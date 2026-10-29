"""
OHOL play statistics from oholcurse.com.
Reads every life of one player (no login needed) and draws summary charts.

Usage:
    python3 ohol_stats.py <player name, URL or hash> [file name] [--include-dt]

Examples:
    python3 ohol_stats.py "Firstname Lastname"
    python3 ohol_stats.py https://oholcurse.com/player/lives/<hash>

Install once:
    pip install requests beautifulsoup4 pandas matplotlib pillow scipy openpyxl
"""

import argparse
import json
import re
from datetime import date, datetime, timedelta
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd
import requests
from bs4 import BeautifulSoup

BASE = "https://oholcurse.com"
UA = "Mozilla/5.0 (ohol-stats script)"
LOCAL_TZ = datetime.now().astimezone().tzinfo
WEEKDAYS = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]


# ---------- Talking to the website ----------
class OholSession:
    """One browser-like session. Livewire needs the same cookies for every call."""

    def __init__(self):
        self.s = requests.Session()
        self.s.headers["User-Agent"] = UA

    def page(self, path, marker_id):
        """Open a page and return its CSRF token, the Livewire snapshot of the
        component that holds the element with id=marker_id, and the parsed page."""
        url = BASE + path
        r = self.s.get(url, timeout=30)
        r.raise_for_status()
        soup = BeautifulSoup(r.text, "html.parser")
        marker = soup.find(id=marker_id)
        comp = marker.find_parent(attrs={"wire:snapshot": True}) if marker else None
        if comp is None:
            raise RuntimeError("Page layout not recognised. The website may have changed.")
        token = soup.find("meta", attrs={"name": "csrf-token"})["content"]
        return token, comp["wire:snapshot"], soup, url

    def call(self, token, snapshot, updates, calls, referer, timeout=60):
        """Send one Livewire update and return the component response."""
        body = {"_token": token,
                "components": [{"snapshot": snapshot, "updates": updates, "calls": calls}]}
        r = self.s.post(f"{BASE}/livewire/update", data=json.dumps(body), timeout=timeout,
                        headers={"Content-Type": "application/json",
                                 "X-Livewire": "", "Referer": referer})
        r.raise_for_status()
        return r.json()["components"][0]


# ---------- Finding a player ----------
SEARCH_FILTERS = [  # (website filter, field with the display name)
    ("leaderboard", "leaderboard_name"),
    ("curse_name", "curse_name"),
    ("character_name", "name"),
]


def _hash_of(rec):
    if rec.get("player_hash"):
        return rec["player_hash"]
    ch = rec.get("character")
    if isinstance(ch, list) and ch and isinstance(ch[0], dict):
        return ch[0].get("player_hash")
    return None


def search_players(query, sess=None):
    """Search oholcurse like the box on its home page.
    Tries leaderboard name, then curse name, then character name.
    Returns a list of (found by, name, hash), one per player."""
    sess = sess or OholSession()
    token, snap0, _, url = sess.page("/", "profileSearch")
    for flt, field in SEARCH_FILTERS:
        snap1 = sess.call(token, snap0, {}, [
            {"path": "", "method": "setSearchFilter", "params": [flt]}], url)["snapshot"]
        snap2 = sess.call(token, snap1, {"query": query}, [
            {"path": "", "method": "search", "params": []}], url)["snapshot"]
        results = json.loads(snap2)["data"]["results"][0]
        recs = [r[0] if isinstance(r, list) else r for r in results]
        found = []
        for rec in recs:
            name, h = rec.get(field) or "", _hash_of(rec)
            if h:
                found.append((flt, name, h))
        if not found:
            continue
        exact = [f for f in found if f[1].strip().lower() == query.strip().lower()]
        found = exact or found
        unique = {}
        for f in found:
            unique.setdefault(f[2], f)
        return list(unique.values())
    return []


def find_player_hash(player, sess=None):
    """Accept a URL, a hash, or a name (leaderboard, curse or character name)."""
    m = re.search(r"[0-9a-fA-F]{40}", player)
    if m:
        return m.group(0).lower()
    hits = search_players(player, sess)
    if not hits:
        raise SystemExit(f'No player found for "{player}". Check the spelling on oholcurse.com.')
    if len(hits) > 1:
        lines = "\n".join(f"  {n}  ({f})  {h}" for f, n, h in hits)
        raise SystemExit(f'Several players match "{player}":\n{lines}\n'
                         "Use the full name in quotes, or one of the hashes.")
    flt, name, h = hits[0]
    print(f"Found {name} by {flt.replace('_', ' ')}")
    return h


# ---------- Reading lives ----------
def parse_lives_table(html, tz=None):
    """Turn the lives table HTML into a data frame."""
    table = BeautifulSoup(html, "html.parser").find("table")
    rows = []
    for tr in table.select("tbody tr"):
        cells = [" ".join(td.get_text(" ").split()) for td in tr.find_all("td")]
        if len(cells) < 7:
            continue
        full_name, life_id, age, sex, location, died_to, died = cells[:7]
        first, _, surname = full_name.partition(" ")
        rows.append({
            "Name": first,
            "Surname": surname or None,
            "Life ID": int(life_id),
            "Age": float(age),
            "Sex": sex,
            "Location": location,
            "Died to": died_to,
            "Died": died,
        })
    df = pd.DataFrame(rows)

    # Deaths by another player show as killer_<their life ID>
    df["Died to"] = df["Died to"].str.replace(r"^killer_\d+$", "killer", regex=True)
    # Without login the site shows UTC, so convert to local time
    df["Died"] = (pd.to_datetime(df["Died"]).dt.tz_localize("UTC")
                  .dt.tz_convert(tz or LOCAL_TZ).dt.tz_localize(None))
    # 1 year of age = 1 minute
    df["Born"] = (df["Died"] - pd.to_timedelta(df["Age"], unit="m")).dt.round("s")
    df["Date"] = df["Born"].dt.strftime("%Y-%m-%d")
    df["Month"] = df["Born"].dt.strftime("%Y-%m")
    df["Day"] = [WEEKDAYS[d] for d in df["Born"].dt.weekday]
    # Donkey Town sits far to the west, around x = -200,000,000.
    # The normal world stays within about a million.
    x = pd.to_numeric(df["Location"].str.split("/").str[0].str.strip(), errors="coerce")
    df["Donkey Town"] = x.le(-1e8).fillna(False)
    return df


def fetch_ohol_lives(player, tz=None, order="desc"):
    """player can be a URL, a hash, or a name."""
    sess = OholSession()
    player_hash = find_player_hash(player, sess)

    # Open the lives page, then do what the PER PAGE = All menu does
    token, snap, soup, url = sess.page(f"/player/lives/{player_hash}", "take")
    player_name = soup.title.get_text().split("Lives for ")[-1].strip()
    comp = sess.call(token, snap, {"take": "99999", "order": order},
                     [{"path": "", "method": "updateLimit", "params": []}], url, timeout=120)

    df = parse_lives_table(comp["effects"]["html"], tz)
    df.attrs["player"] = player_name
    print(f"Read {len(df)} lives for {player_name}")
    return df


# ---------- Plot helpers ----------
def bar_with_labels(ax, x, y, labels, color="skyblue"):
    ax.bar(x, y, color=color)
    for xi, yi, lab in zip(x, y, labels):
        ax.text(xi, yi, lab, ha="center", va="bottom", fontsize=9)


def top10_barh(ax, counts, title, ylabel, color):
    top = counts.head(10)[::-1]
    ax.barh(top.index, top.values, color=color)
    for i, v in enumerate(top.values):
        ax.text(v, i, f" {v}", va="center", fontsize=9)
    ax.set_title(title, loc="left")
    ax.set_xlabel("Frequency")
    ax.set_ylabel(ylabel)
    ax.margins(x=0.08)


def clean_axes(ax):
    ax.grid(True, color="#e5e5e5", linewidth=0.8)
    ax.set_axisbelow(True)
    for sp in ax.spines.values():
        sp.set_visible(False)


# ---------- Charts ----------
def make_plots(data, name, out_dir):
    data = data.copy()
    data["Died to"] = data["Died to"].where(
        ~data["Died to"].str.contains("Boar", case=False, na=False), "Boar")  # merge all boar types

    fig, axes = plt.subplots(5, 2, figsize=(14, 18))
    ax = axes.ravel()

    # 1. Lives per hour of birth
    hours = data["Born"].dt.hour.value_counts().reindex(range(24), fill_value=0)
    bar_with_labels(ax[0], [f"{h:02d}" for h in range(24)], hours.values, hours.values)
    ax[0].set(title="Online Hours", xlabel="Hours", ylabel="Frequency")

    # 2. Lives per weekday
    week = data["Day"].value_counts().reindex(WEEKDAYS, fill_value=0)
    bar_with_labels(ax[1], WEEKDAYS, week.values, week.values)
    ax[1].set(title="My Online Days of the Week", xlabel="Day of the Week", ylabel="Frequency")

    # 3. Lives per month, up to this month
    months = pd.period_range(data["Born"].min(), pd.Timestamp.today(), freq="M").strftime("%Y-%m")
    monthly = data["Month"].value_counts().reindex(months, fill_value=0)
    ax[2].plot(monthly.index, monthly.values, color="skyblue", linewidth=2.5)
    ax[2].scatter(monthly.index, monthly.values, color="orange", s=30, zorder=3)
    for x, y in zip(monthly.index, monthly.values):
        ax[2].text(x, y, str(y), ha="center", va="bottom", fontsize=7)
    ax[2].set_title("Monthly Frequency", fontweight="bold", fontsize=14)
    ax[2].set(xlabel="Month", ylabel="Frequency")
    ax[2].tick_params(axis="x", rotation=45)
    plt.setp(ax[2].get_xticklabels(), ha="right")

    # 4. Age density (60 and under)
    ages = data.loc[data["Age"] <= 60, "Age"]
    try:
        ages.plot.kde(ax=ax[3], color="black", bw_method="scott")
        line = ax[3].get_lines()[-1]
        xs, ys = line.get_data()
        keep = (xs >= ages.min()) & (xs <= ages.max())
        line.set_data(xs[keep], ys[keep])
        ax[3].fill_between(xs[keep], ys[keep], color="#D3A9C9")
        ax[3].set_xlim(ages.min(), ages.max())
    except Exception:  # without scipy, draw a histogram
        ax[3].hist(ages, bins=30, color="#D3A9C9", density=True)
    ax[3].set(title="Density Plot of Ages (Age <= 60)", xlabel="Age", ylabel="Density")

    # 5. Top 10 causes of death
    top10_barh(ax[4], data["Died to"].value_counts(), "My Top 10 Died to Reasons",
               "Died to", "lightblue")

    # 6. Sex
    sex = data["Sex"].value_counts().sort_index()
    ax[5].pie(sex.values, labels=sex.index, autopct="%.1f%%", startangle=90,
              colors=["#F8766D", "#00BFC4", "#999999"][:len(sex)],
              textprops={"color": "black"}, wedgeprops={"edgecolor": "white"})
    ax[5].set_title("My Characters Sex Distribution")

    # 7. Top 10 first names (without EVE)
    names = data.loc[data["Name"].notna() & (data["Name"] != "EVE"), "Name"].value_counts()
    top10_barh(ax[6], names, "Top 10 Names (Excluding 'EVE')", "Name", "lightcoral")

    # 8. Top 10 surnames
    top10_barh(ax[7], data["Surname"].dropna().value_counts(), "My Top 10 Surnames",
               "Surname", "skyblue")

    # 9. Hours played per day
    d = data[data["Born"].dt.date <= date.today()].copy()
    d["hours"] = (d["Died"] - d["Born"]).dt.total_seconds() / 3600
    daily = d[d["hours"] > 0].groupby(d["Born"].dt.normalize())["hours"].sum()
    daily = daily.reindex(pd.date_range(daily.index.min(), daily.index.max()), fill_value=0)
    ax[8].bar(daily.index, daily.values, color="steelblue", alpha=0.8, width=1)
    played = daily[daily > 0]
    ax[8].scatter(played.index, played.values, color="orange", s=8, zorder=3)
    ax[8].set_title("Daily Playtime", fontweight="bold")
    ax[8].set(xlabel="Date", ylabel="Hours per Day")
    ax[8].xaxis.set_major_locator(plt.matplotlib.dates.MonthLocator())
    ax[8].xaxis.set_major_formatter(plt.matplotlib.dates.DateFormatter("%Y-%m"))
    ax[8].tick_params(axis="x", rotation=45)
    plt.setp(ax[8].get_xticklabels(), ha="right")

    ax[9].axis("off")
    for a in ax[:9]:
        if a is not ax[5]:
            clean_axes(a)
    for a in (ax[0], ax[1]):
        a.margins(y=0.1)

    # Total hours as the big title
    total = (data["Died"] - data["Born"]).dt.total_seconds().sum() / 3600
    fig.suptitle(f"Total Online Hours: {total:.2f} hours", fontsize=16, fontweight="bold")
    fig.tight_layout(rect=(0, 0, 1, 0.97))

    out = out_dir / f"OHOL_stats_{name}_{date.today() - timedelta(days=1)}.jpg"
    fig.savefig(out, dpi=300, facecolor="white")
    plt.close(fig)
    print("Saved:", out)
    return out


def main():
    ap = argparse.ArgumentParser(description="OHOL play statistics from oholcurse.com")
    ap.add_argument("player", help="leaderboard, curse or character name, or the player URL or hash")
    ap.add_argument("name", nargs="?", default="",
                    help="name used in file names (default: the name on the website)")
    ap.add_argument("--tz", default=None,
                    help='time zone, for example "America/Toronto" (default: this computer)')
    ap.add_argument("--out", default="output", help="output folder (default: output)")
    ap.add_argument("--include-dt", action="store_true",
                    help="also count lives in Donkey Town (left out by default)")
    a = ap.parse_args()

    data = fetch_ohol_lives(a.player, tz=a.tz)
    name = a.name or re.sub(r"[^A-Za-z0-9]+", "", data.attrs["player"])
    out_dir = Path(a.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    cols = ["Date", "Month", "Day", "Name", "Surname", "Life ID", "Age", "Sex",
            "Location", "Died to", "Born", "Died", "Donkey Town"]
    data[cols].to_csv(out_dir / f"OHOL_lives_{name}.csv", index=False)
    data[cols].to_excel(out_dir / f"OHOL_lives_{name}.xlsx", sheet_name="Record", index=False)

    # The files above keep every life. The charts leave out Donkey Town unless --include-dt is given.
    if not a.include_dt:
        n_dt = int(data["Donkey Town"].sum())
        if n_dt:
            print(f"Left out {n_dt} Donkey Town lives. Use --include-dt to count them.")
        data = data[~data["Donkey Town"]].copy()
    make_plots(data, name, out_dir)


if __name__ == "__main__":
    main()
