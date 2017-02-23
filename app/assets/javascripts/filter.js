function filterText(){
	$('tr').show();
	var searchText = $('#search-text').val();
	
	var hide = $('tr:not(:contains("Exchange")):not(:contains("'+searchText+'"))');
	$.each(hide, function(){ $(this).hide() });
}

$(document).ready(function(){
	$('#search-text').keyup(filterText);
});