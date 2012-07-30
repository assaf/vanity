var Vanity = {}
Vanity.tooltip = function(event, pos, item) {
  if (item) {
    if (this.previousPoint != item.datapoint) {
      this.previousPoint = item.datapoint;
      $("#tooltip").remove();
      var y = item.datapoint[1].toFixed(2);
      var dt = new Date(parseInt(item.datapoint[0], 10));
      $('<div id="tooltip">' + dt.getUTCFullYear() + '-' + (dt.getUTCMonth() + 1) + '-' + dt.getUTCDate() + "<br>" + y + '</div>').css( {
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

  metric.plot = function(lines) {
    $.each(lines, function(i, line) {
      $.each(line.data, function(i, pair) { pair[0] = Date.parse(pair[0]) })
    });
    var plot = $.plot(metric.chart, lines, metric.options);
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
      var start = Date.parse($(this).attr("data-start"));
      var end = Date.parse($(this).attr("data-end"));
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

  function post_on_click(sel) {
    $(sel).live("click", function() {
      var link = $(this);
      $.ajax({
        data: 'authenticity_token=' + encodeURIComponent(document.auth_token),
        success: function(request){ $('#experiment_' + link.attr("data-id")).html(request) },
        url: link.attr("data-url"), type: 'post'
      });
      return false;
    });
  }

  post_on_click(".experiment.ab_test a.button.chooses");
  post_on_click(".experiment.ab_test .enabled-links a");

  $(".experiment button.reset").live("click", function() {
    if (confirm('Are you sure you want to reset the experiment? This will clear all collected data so far and restart the experiment from scratch. This cannot be undone.')){
      var link = $(this);
      $.ajax({
        data: 'authenticity_token=' + encodeURIComponent(document.auth_token),
        success: function(request){ $('#experiment_' + link.attr("data-id")).html(request) },
        url: link.attr("data-url"), type: 'post'
      });
    }
    return false;
  });
  
  $(".experiment button.finish").live("click", function() {
    var link = $(this);
    if (confirm('Are you sure you want to complete the experiment and set ' + link.attr("alt-name") + ' as the outcome?')){
      $.ajax({
        data: 'authenticity_token=' + encodeURIComponent(document.auth_token),
        success: function(request){ $('#experiment_' + link.attr("data-id")).html(request) },
        url: link.attr("data-url"), type: 'post'
      });
    }
    return false;
  });
});
