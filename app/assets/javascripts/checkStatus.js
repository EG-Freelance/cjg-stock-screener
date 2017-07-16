function checkBackground() {
	
	function clearI(interval) {
		clearInterval(interval);
	}
	
	$('#check-bg').click(function(){
		setTimeout(function(){
			$('#polling-alert').css('visibility', 'visible');
			var i = 0;
			var sum = parseInt($('#import-workers').text()) + parseInt($('#screen-workers').text()) + parseInt($('#display-workers').text()) + parseInt($('#earnings-workers').text());
			var interval = setInterval(function(){
				if(sum == 0 || i == 60){ 
					clearI(interval); 
					$('#polling-alert').css('visibility', 'hidden');
				}
				sum = parseInt($('#import-workers').text()) + parseInt($('#screen-workers').text()) + parseInt($('#display-workers').text()) + parseInt($('#earnings-workers').text());
				$('#check-bg').trigger('click');
				i++;
			},1000);
		},500);
	});
	
}

$(document).ready(checkBackground);