function updateActions() {
	var oldText;
	var newText;
	var submitId;
	$('.action-field').focusin(function(){
		oldText = $(this).val();
		submitId = $(this).attr('id').replace('action', 'submit');
	});
	
	$('.action-field').focusout(function(){
		newText = $(this).val();
		if(newText == oldText){
			return false
		}else{
			$('#'+submitId).trigger('click');
		}
	});
}

$(document).ready(updateActions);