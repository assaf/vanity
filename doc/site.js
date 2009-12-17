$(function() {
  var issuesTable = $("table#issues");
  if (issuesTable.size() > 0) {
    $.getJSON("http://github.com/api/v2/json/issues/list/assaf/vanity/open?callback=?", function(response) {
      $.each(response.issues, function(i, issue) {
        issuesTable.append(
          $("<tr>").append(
            $("<td>").append(
              $("<a>").text(issue.title).attr("href", "http://github.com/assaf/vanity/issues#issue/" + issue.number)
            ).append(
              $("<span class='votes'>").text(issue.votes == 0 ? "no votes" : issue.votes == 1 ? "1 vote" : issue.votes + " votes")
            )
          )
        );
      });
    });
  }

  var statsTable = $("#sidebar ul#stats");
  if (statsTable.size() > 0) {
    $.getJSON("http://github.com/api/v2/json/repos/show/assaf/vanity?callback=?", function(response) {
      statsTable.find("li.watchers").append(response.repository.watchers);
      statsTable.find("li.forks").append(response.repository.forks);
    });
    $.getJSON("http://gemcutter.org/api/v1/gems/vanity.json", function(response) { 
      statsTable.find("li.downloads").append(response.downloads);
    });
  }
});
