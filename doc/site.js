$(function() {
  var statsTable = $("#sidebar ul#stats");
  if (statsTable.size() > 0) {
    $.getJSON("http://github.com/api/v2/json/repos/show/assaf/vanity?callback=?", function(response) {
      statsTable.
        prepend( $("<li>").append("Forks: " + response.repository.forks) ).
        prepend( $("<li>").append("Watchers: " + response.repository.watchers) )
    })
  }
});
