$ ->
  $(".avl-btn-danger, .avl-btn-success, .avl-btn").click ->
    $(this).addClass("avl-btn-active")

    $(this).html("sending...")
    $(this).val("sending...")

    unless $(this).data("action") == "sending"
      $(this).data("action", "sending")

    return true
