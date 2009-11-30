var Vanity = {
  tooltip: function(event, pos, item) {
    if (item) {
      if (this.previousPoint != item.datapoint) {
        this.previousPoint = item.datapoint;
        $("#tooltip").remove();
        var x = item.datapoint[0].toFixed(2), y = item.datapoint[1].toFixed(2);
        $('<div id="tooltip">' + new Date(parseInt(x, 10)).toDateString() + "&mdash;" + y + '</div>').css( {
          position: 'absolute', display: 'none',
          top: item.pageY + 5, left: item.pageX + 5,
          padding: '2px', border: '1px solid #ff8', 'background-color': '#ffe', opacity: 0.9
        }).appendTo("body").fadeIn(200);
      }
    } else {
      $("#tooltip").remove();
      this.previousPoint = null;            
    }
  },

  metric: function(id) {      
    var metric = {};
    metric.chart = $("#metric_" + id + " .chart");
    metric.chart.height(metric.chart.width() / 7);
    metric.markings = [];
    metric.options = {
      xaxis:  { mode: "time", minTickSize: [7, "day"] },
      yaxis:  { ticks: [0, 100], autoscaleMargin: null },
      series: { lines: { show: true, lineWidth: 2, fill: true, fillColor: { colors: ["#fff", "#C6D2DA"] } },
                points: { show: false, radius: 1 }, shadowSize: 0 },
      colors: ["#0077CC"],
      legend: { position: 'sw', container: "#metric_" + id +" .legend", backgroundOpacity: 0.5 },
      grid:   { markings: metric.markings, borderWidth: 0, backgroundColor: "#fff", hoverable: true } };

    metric.plot = function(lines) {
      var min, max;
      $.each(lines[0].data, function(i, val) { var y = val[1];
        if (max == null || y > max) max = y;
        if (min == null || y < min) min = y;
      });
      if (min == null) min = max = 0;
      metric.options.yaxis.ticks = [min, (min + max) / 2.0, max];
      var plot = $.plot(metric.chart, lines, metric.options);
      jQuery.each(metric.markings, function(i, mark) { 
        $('<div style="position:absolute;top:5%;color:#f02020;font-size:smaller"></div>').
          css({left:plot.pointOffset({x:mark.xaxis.from}).left+4}).text(mark.text).appendTo(chart);
      });
      metric.chart.bind("plothover", Vanity.tooltip);
    }
    return metric;
  }

}
