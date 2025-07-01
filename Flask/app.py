import itertools
import pandas as pd
import plotly.graph_objects as go
import plotly
import json
from flask import Flask, render_template

app = Flask(__name__)

# ——— PREP DATA & FIGURE ———

df = pd.read_csv(
    "https://raw.githubusercontent.com/Ramil-cyber/Research_Linking_Analyzing_Deaths_US_Prisons/refs/heads/main/Data/Last_merged_full_df.csv",
    low_memory=False,
)

agg = (
    df.groupby(["state_name", "state_abbr", "death_year"], as_index=False)
      .agg({
          "death_count": "sum",
          "total_pop_15to64": "first",
          "female_pop_15to64": "first",
          "male_pop_15to64": "first",
          "aapi_pct": "first",
          "black_pct": "first",
          "latinx_pct": "first",
          "native_pct": "first",
          "white_pct": "first",
          "total_prison_pop": "first",
          "female_prison_pop": "first",
          "male_prison_pop": "first",
          "prison_death_rate": "first",
          "total_prisoners_rate": "first"
      })
)
agg["female_pct"] = (agg.female_pop_15to64 / agg.total_pop_15to64 * 100).fillna(0)
agg["male_pct"]   = (agg.male_pop_15to64 / agg.total_pop_15to64 * 100).fillna(0)

# pad missing state×year combos
all_states = sorted(agg.state_abbr.unique())
all_years  = sorted(agg.death_year.unique())
full_index = pd.DataFrame(
    itertools.product(all_states, all_years),
    columns=["state_abbr", "death_year"]
)
agg = (
    full_index
    .merge(agg, on=["state_abbr", "death_year"], how="left")
    .assign(
        state_name=lambda d: d.state_abbr.map(
            agg.drop_duplicates("state_abbr").set_index("state_abbr")["state_name"]
        ),
        death_count=lambda d: d.death_count.fillna(0),
        total_pop_15to64=lambda d: d.total_pop_15to64.fillna(0),
        female_pct=lambda d: d.female_pct.fillna(0),
        male_pct=lambda d: d.male_pct.fillna(0),
        aapi_pct=lambda d: d.aapi_pct.fillna(0),
        black_pct=lambda d: d.black_pct.fillna(0),
        latinx_pct=lambda d: d.latinx_pct.fillna(0),
        native_pct=lambda d: d.native_pct.fillna(0),
        white_pct=lambda d: d.white_pct.fillna(0),
        total_prison_pop=lambda d: d.total_prison_pop.fillna(0),
        female_prison_pop=lambda d: d.female_prison_pop.fillna(0),
        male_prison_pop=lambda d: d.male_prison_pop.fillna(0),
        prison_death_rate=lambda d: d.prison_death_rate.fillna(0),
        total_prisoners_rate=lambda d: d.total_prisoners_rate.fillna(0),
    )
)

# centroids for labels
state_centroids = {
    "AL": {"lat": 32.8067, "lon": -86.7911},
    "AK": {"lat": 61.3707, "lon": -152.4044},
    "AZ": {"lat": 33.7298, "lon": -111.4312},
    "AR": {"lat": 34.9697, "lon": -92.3731},
    "CA": {"lat": 36.1162, "lon": -119.6816},
    "CO": {"lat": 39.0598, "lon": -105.3111},
    "CT": {"lat": 41.5978, "lon": -72.7554},
    "DE": {"lat": 39.3185, "lon": -75.5071},
    "DC": {"lat": 38.8974, "lon": -77.0268},
    "FL": {"lat": 27.7663, "lon": -81.6868},
    "GA": {"lat": 33.0406, "lon": -83.6431},
    "HI": {"lat": 21.0943, "lon": -157.4983},
    "ID": {"lat": 44.2405, "lon": -114.4788},
    "IL": {"lat": 40.3495, "lon": -88.9861},
    "IN": {"lat": 39.8494, "lon": -86.2583},
    "IA": {"lat": 42.0115, "lon": -93.2105},
    "KS": {"lat": 38.5266, "lon": -96.7265},
    "KY": {"lat": 37.6681, "lon": -84.6701},
    "LA": {"lat": 31.1695, "lon": -91.8678},
    "ME": {"lat": 44.6939, "lon": -69.3819},
    "MD": {"lat": 39.0639, "lon": -76.8021},
    "MA": {"lat": 42.2302, "lon": -71.5301},
    "MI": {"lat": 43.3266, "lon": -84.5361},
    "MN": {"lat": 45.6945, "lon": -93.9002},
    "MS": {"lat": 32.7416, "lon": -89.6787},
    "MO": {"lat": 38.4561, "lon": -92.2884},
    "MT": {"lat": 46.9219, "lon": -110.4544},
    "NE": {"lat": 41.1254, "lon": -98.2681},
    "NV": {"lat": 38.3135, "lon": -117.0554},
    "NH": {"lat": 43.4525, "lon": -71.5639},
    "NJ": {"lat": 40.2989, "lon": -74.5210},
    "NM": {"lat": 34.8405, "lon": -106.2485},
    "NY": {"lat": 42.1657, "lon": -74.9481},
    "NC": {"lat": 35.6301, "lon": -79.8064},
    "ND": {"lat": 47.5289, "lon": -99.7840},
    "OH": {"lat": 40.3888, "lon": -82.7649},
    "OK": {"lat": 35.5653, "lon": -96.9289},
    "OR": {"lat": 44.5720, "lon": -122.0709},
    "PA": {"lat": 40.5908, "lon": -77.2098},
    "RI": {"lat": 41.6809, "lon": -71.5118},
    "SC": {"lat": 33.8569, "lon": -80.9450},
    "SD": {"lat": 44.2998, "lon": -99.4388},
    "TN": {"lat": 35.7478, "lon": -86.6923},
    "TX": {"lat": 31.0545, "lon": -97.5635},
    "UT": {"lat": 40.1500, "lon": -111.8624},
    "VT": {"lat": 44.0459, "lon": -72.7107},
    "VA": {"lat": 37.7693, "lon": -78.1699},
    "WA": {"lat": 47.4009, "lon": -121.4905},
    "WV": {"lat": 38.4912, "lon": -80.9545},
    "WI": {"lat": 44.2685, "lon": -89.6165},
    "WY": {"lat": 42.7560, "lon": -107.3025}
}

# build figure
fig = go.Figure()
zmax = agg.death_count.max()

for i, yr in enumerate(all_years):
    dff = agg[agg.death_year == yr]
    # choropleth
    fig.add_trace(go.Choropleth(
        locations=dff.state_abbr,
        locationmode="USA-states",
        z=dff.death_count,
        zmin=0, zmax=zmax,
        colorscale="Greens",
        marker_line_color="black", marker_line_width=0.5,
        colorbar=dict(title="Deaths", x=1),
        customdata=dff[[
            "state_name","total_pop_15to64","female_pct","male_pct",
            "aapi_pct","black_pct","latinx_pct","native_pct","white_pct",
            "total_prison_pop","female_prison_pop","male_prison_pop",
            "death_count","prison_death_rate","total_prisoners_rate"
        ]].values,
        hovertemplate=(
             "<b>%{customdata[0]}</b><br>"
                "Total State Population at 15-64 years old: %{customdata[1]:,}<br>"
                "Female Population: %{customdata[2]:.1f}%<br>"
                "Male Population: %{customdata[3]:.1f}%<br>"
                "Asian American/Pacific Islander: %{customdata[4]:.1f}%<br>"
                "Black: %{customdata[5]:.1f}%<br>"
                "Hispanic/Latino: %{customdata[6]:.1f}%<br>"
                "Native: %{customdata[7]:.1f}%<br>"
                "White: %{customdata[8]:.1f}%<extra></extra>"
                "Total Prisoners: %{customdata[9]:,}<br>"
                "Female Prisoners: %{customdata[10]:,}<br>"
                "Male Prisoners: %{customdata[11]:,}<br>"
                "Prisoner Deaths: %{customdata[12]:,}<br>"
                "Prisoner Death Rate: %{customdata[13]:,}<br>"
                "Total Prisoners Rate: %{customdata[14]:,}<br>"
                "<extra></extra>" 
        ),
        visible=(i == 0)
    ))
    # state labels
    lons = [state_centroids[s]["lon"] for s in dff["state_abbr"]]
    lats = [state_centroids[s]["lat"] for s in dff["state_abbr"]]
    fig.add_trace(
        go.Scattergeo(
            lon=lons,
            lat=lats,
            text=dff["state_abbr"],
            mode="text",
            showlegend=False,
            hoverinfo="none",
            textfont=dict(size=9, color="black"),
            visible=(i == 0),
        )
    )

# Year dropdown

year_buttons = []
for idx, yr in enumerate(all_years):
    vis = [False] * (2 * len(all_years))
    vis[2 * idx] = vis[2 * idx + 1] = True
    year_buttons.append(
        dict(
            label=str(yr),
            method="update",
            args=[{"visible": vis}, {"title": f"US Prisoner Deaths — {yr}"}],
        )
    )

# State dropdown

chor_indices = list(range(0, 2 * len(all_years), 2))
pairs = agg.drop_duplicates(["state_abbr", "state_name"])[["state_abbr", "state_name"]]
pairs = pairs.sort_values("state_name").values.tolist()

state_buttons = [
    dict(
        label="All States",
        method="restyle",
        args=[
            {
                "z": [
                    agg[agg["death_year"] == yr]["death_count"].tolist()
                    for yr in all_years
                ]
            },
            chor_indices,
        ],
    )
]
for abbr, name in pairs:
    z_series = []
    for yr in all_years:
        counts = agg[agg["death_year"] == yr].set_index("state_abbr")["death_count"]
        z_series.append([counts.get(s, 0) if s == abbr else 0 for s in all_states])
    state_buttons.append(
        dict(
            label=f"{abbr} ({name})",
            method="restyle",
            args=[{"z": z_series}, chor_indices],
        )
    )

# Layout & display

fig.update_layout(
    title=f"US Prisoner Deaths — {all_years[0]}",
    updatemenus=[
        dict(
            x=0.01,
            y=0.92,
            direction="down",
            buttons=year_buttons,
            pad=dict(r=10, t=10),
            showactive=True,
        ),
        dict(
            x=0.01,
            y=0.80,
            direction="down",
            buttons=state_buttons,
            pad=dict(r=10, t=10),
            showactive=True,
        ),
    ],
    geo=dict(scope="usa", showlakes=True, lakecolor="white", bgcolor="#F0F0F0"),
    margin=dict(l=0, r=0, t=80, b=0),
)

# serialize
graphJSON = json.dumps(fig, cls=plotly.utils.PlotlyJSONEncoder)


@app.route("/")
def index():
    return render_template("index.html", graphJSON=graphJSON)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)