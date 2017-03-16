function updateActions() {
	var oldText;
	var newText;
	var submitId;
	var el;
	$('.action-field').focusin(function(){
		oldText = $(this).val();
		el = $(this);
		submitId = $(this).attr('id').replace('action', 'submit');
		
		// set function for exit of this field
		el.focusout(function(){
			newText = $(this).val();
			if(newText == oldText){
				return false
			}else{
				$('#'+submitId).trigger('click');
			}
		});
	});
	
}

$(document).ready(updateActions);