import plotly
from flask import Flask, render_template
import plotly.graph_objs as go
import json

app = Flask(__name__)

@app.route('/')
def index():
    # Sample Plotly graph (a simple line chart)
    data = [
        go.Scatter(
            x=[1, 2, 3, 4, 5],
            y=[10, 14, 18, 24, 30],
            mode='lines+markers',
            name='Line Plot'
        )
    ]

    layout = go.Layout(title='Simple Plotly Line Chart')
    graphJSON = json.dumps({'data': data, 'layout': layout}, cls=plotly.utils.PlotlyJSONEncoder)

    return render_template("index.html", graphJSON=graphJSON)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=True)

