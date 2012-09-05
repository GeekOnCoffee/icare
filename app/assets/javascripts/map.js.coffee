###global google:false###
###jshint shadow:true###

"use strict"

window.icare = window.icare || {}
icare = window.icare

class CustomMarker
  @::= new google.maps.OverlayView()

  constructor: (@position, map, opts) ->
    @_div = null
    @setMap map
    $.extend true, @options =
     infoWindowContent: null
     image: "http://placehold.it/50x50"
     css_classes: "markers-home"
     type: "sprite"
     image_overlay: null
    , opts

  onAdd: ->
    me = @
    div = document.createElement 'div'
    div.style.position = "absolute"

    switch @options.type
      when "user_profile_picture"
        div.setAttribute "class", "#{@options.css_classes} arrow_box"
        div.style.width = '31px'
        div.style.height = '31px'
        img = document.createElement 'img'
        img.setAttribute "width", "25px"
        img.setAttribute "height", "25px"
        img.setAttribute "alt", ""
        img.src = @options.image
        div.appendChild img
      when "sprite"
        div.setAttribute "class", @options.css_classes
        div.style.border = "0px solid none"
        div.style.width = '32px'
        div.style.height = '37px'
        div.style.cursor = 'pointer'

    @_div = div

    @getPanes().overlayMouseTarget.appendChild div

    google.maps.event.addDomListener div, 'click', ->
      google.maps.event.trigger me, 'click'

  draw: ->
    point = @getProjection().fromLatLngToDivPixel @position
    width = parseInt @_div.style.width, 10
    height = parseInt @_div.style.height, 10
    height += 5 if @type is "user_profile_picture"
    if point
      @_div.style.left = "#{point.x - width/2}px"
      @_div.style.top = "#{point.y - height}px"
    return

  onRemove: ->
    if @_div
      @_div.parentNode.removeChild @_div
      @_div = null
    return

window.icare.CustomMarker = CustomMarker

random_nearby_position = (latLng, maxDist = 0.5, km = true) ->
  #very very very very special thanks to http://www.geomidpoint.com/random/calculation.html
  DEG_TO_RAD = Math.PI / 180
  RAD_TO_DEG = 180 / Math.PI
  startlat = latLng[0] * DEG_TO_RAD
  startlng = latLng[1] * DEG_TO_RAD
  rand1 = Math.random()
  rand2 = Math.random()
  radiusEarthM = 3960.056052
  radiusEarthKm = 6372.796924
  maxDistRad = maxDist / (if km then radiusEarthKm else radiusEarthM)
  dist = Math.acos(rand1 * (Math.cos(maxDistRad) - 1) + 1)
  brg = 2 * Math.PI * rand2
  lat = Math.asin( Math.sin(startlat) * Math.cos(dist) + Math.cos(startlat) * Math.sin(dist) * Math.cos(brg) )
  lng = startlng + Math.atan2( Math.sin(brg) * Math.sin(dist) * Math.cos(startlat), Math.cos(dist) - Math.sin(startlat) * Math.sin(lat) )
  if (lng < -1 * Math.PI)
    lng = lng + 2 * Math.PI
  else if (lng > Math.PI)
    lng = lng - 2 * Math.PI
  [lat * RAD_TO_DEG, lng * RAD_TO_DEG]
