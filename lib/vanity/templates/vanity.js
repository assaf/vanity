var Vanity = {}
Vanity.tooltip = function(event, pos, item) {
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
}

Vanity.metric = function(id) {      
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
    grid:   { markings: metric.markings, borderWidth: 1, borderColor: '#eee', hoverable: true, aboveData: true } };

  metric.mark = function(start, end, label) { 
    metric.markings.push({color: "#f02020", xaxis: { from: start, to: start + 4 * 3600 * 1000 }, text: label});
    metric.markings.push({color: "#f02020", xaxis: { from: end, to: end + 4 * 3600 * 1000 }});
  }
  metric.plot = function(lines) {
    var min, max;
    $.each(lines[0].data, function(i, val) { var y = val[1];
      if (max == null || y > max) max = y;
      if (min == null || y < min) min = y;
    });
    if (min == null) min = max = 0;
    metric.options.yaxis.ticks = [min, (min + max) / 2.0, max];
    var plot = $.plot(metric.chart, lines, metric.options);
    $.each(metric.markings, function(i, mark) { 
      if (mark.xaxis && mark.xaxis.from && mark.label) {
        var o = plot.pointOffset({x:mark.xaxis.from, y:max / 10 - min});
        $('<div style="position:absolute;bottom:2em;color:#f02020;font-size:80%"></div>').
          css({left:o.left+4, top:o.top-4}).text(mark.text).appendTo(metric.chart);
      }
    });
    metric.chart.bind("plothover", Vanity.tooltip);
    metric.chart.data('plot', plot);
  }
  return metric;
}

$(function() {
  var checkboxes = $("#milestones input:checkbox");
  checkboxes.bind("change", function() {
    var markings = [];
    checkboxes.filter(":checked").each(function(i, checkbox) {
      var start = parseInt($(this).attr("data-start"), 10) * 1000;
      var end = parseInt($(this).attr("data-end"), 10) * 1000;
      var title = $(this).parent().text();
      markings.push({color: "#c66", xaxis: { from: start - 20000000, to: start }, label: title});
      if (end > start)
        markings.push({color: "#c99", xaxis: { from: end, to: end + 20000000 }});
    });
    $(".metric .marking.label").remove();
    $(".metric .chart").each(function() {
      var chart = $(this);
      var plot = chart.data('plot');
      plot.getOptions().grid.markings = markings;
      plot.draw();
      $.each(markings, function(i, mark) {
        if (mark.xaxis && mark.xaxis.from && mark.label) {
          var o = plot.pointOffset({x:mark.xaxis.from});
          $('<div class="marking label"></div>').css({left:o.left+4}).text(mark.label).appendTo(chart);
        }
      });
    });
  });

  $(".experiment.ab_test a.button.chooses").live("click", function() {
    var link = $(this);
    $.ajax({
      data: 'authenticity_token=' + encodeURIComponent(document.auth_token),
      success: function(request){ $('#experiment_' + link.attr("data-id")).html(request) },
      url: link.attr("data-url"), type: 'post'
    });
    return false;
  });
});
