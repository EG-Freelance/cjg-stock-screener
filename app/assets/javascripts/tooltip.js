function toggleTooltips() {
  $('td').mouseenter(function(){
    $(this).children().children().children().show();
  });
  
  $('td').mouseleave(function(){
    $(this).children().children().children().hide();
  });
}

$(document).ready(setTimeout(toggleTooltips,1000));
//$(document).ready(setTimeout(tableChange,1000));
$(document).keypress(function(){
  $('table').trigger('update');
});

$(document).keyup(function(){
  setTimeout(toggleTooltips,100);
});

$(document).mouseup(function(){
  setTimeout(toggleTooltips,1000);
});