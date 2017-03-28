// script to allow for case-insensitive filtering
$.extend($.expr[':'], {
  'containsi': function(elem, i, match, array)
  {
    return (elem.textContent || elem.innerText || '').toLowerCase()
    .indexOf((match[3] || "").toLowerCase()) >= 0;
  }
});

function unhideFiltered(){
	$('tr.hide:not(.filter-hide, .na-hide, .hold-hide)').removeClass('hide');
}

function filterMultiText(){
	$('tr.filter-hide').removeClass('filter-hide');
	unhideFiltered();
	var searchText2 = $('#search-text-2').val().replace(/\s\|\|\s/g,"||");
	var searchText2String = searchText2.split("||").map(function(e){ return ':not(:containsi("'+e+'"))' }).join("")
	
	var hide = $('tr:not(.tablesorter-headerRow)'+searchText2String);
	$.each(hide, function(){ $(this).addClass('hide filter-hide') });
	$('tr:not(.hide):even').addClass('even').removeClass('odd');
	$('tr:not(.hide):odd').addClass('odd').removeClass('even');
}

function autoFilterNa(){
	$('tr.na-hide').removeClass('na-hide');
	unhideFiltered();
	if($('#hide-na').prop('checked') == true){
		var filterText = "(n/a)"
	
		var hide = $('tr:not(.tablesorter-headerRow) td:nth-child(6):contains('+filterText+')').parent();
		$.each(hide, function(){ $(this).addClass('hide na-hide') });
		$('tr:not(.hide):even').addClass('even').removeClass('odd');
		$('tr:not(.hide):odd').addClass('odd').removeClass('even');
	}
}

function autoFilterHolds(){
	$('tr.hold-hide').removeClass('hold-hide');
	unhideFiltered();
	if($('#hide-holds').prop('checked') == true){
		var filterText = "HOLD"
	
		var hide = $('tr:not(.tablesorter-headerRow) td:nth-child(6):contains('+filterText+')').parent();
		$.each(hide, function(){ $(this).addClass('hide hold-hide') });
		$('tr:not(.hide):even').addClass('even').removeClass('odd');
		$('tr:not(.hide):odd').addClass('odd').removeClass('even');
	}
}

$(document).ready(function(){
	$('#search-text-2').keyup(filterMultiText);
	$('#hide-na').change(autoFilterNa);
	$('#hide-holds').change(autoFilterHolds);
});