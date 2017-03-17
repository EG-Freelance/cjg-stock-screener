// script to allow for case-insensitive filtering
$.extend($.expr[':'], {
  'containsi': function(elem, i, match, array)
  {
    return (elem.textContent || elem.innerText || '').toLowerCase()
    .indexOf((match[3] || "").toLowerCase()) >= 0;
  }
});

function filterMultiText(){
	$('tr').show();
	var searchText2 = $('#search-text-2').val().replace(/\s\|\|\s/g,"||");
	var searchText2String = searchText2.split("||").map(function(e){ return ':not(:containsi("'+e+'"))' }).join("")
	
	var hide = $('tr:not(:contains("Exchange"))'+searchText2String);
	$.each(hide, function(){ $(this).hide() });
}


$(document).ready(function(){
	//$('#search-text').keyup(filterText);
	$('#search-text-2').keyup(filterMultiText);
});