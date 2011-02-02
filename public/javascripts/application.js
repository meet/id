document.observe('dom:loaded', function() {
  // Old browsers don't show input placeholder text
  function supports_input_placeholder() {
    var i = document.createElement('input');
    return 'placeholder' in i;
  }
  if ( ! supports_input_placeholder()) {
    var width = 0;
    $$('label.fallback').each(function(elt) {
      elt.setStyle({ display: 'inline-block' });
      width = Math.max(width, elt.getWidth());
    });
    $$('label.fallback').each(function(elt) {
      elt.setStyle({ width: width+'px' });
    });
  }
});
