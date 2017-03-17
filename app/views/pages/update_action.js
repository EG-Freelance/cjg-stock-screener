$('#js-notice').html("Action updated");

setTimeout(function(){$('#js-notice').html("")}, 3000);

$('#<%= @id %>').html("<%= @description %>");