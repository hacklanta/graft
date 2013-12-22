window.htmlize = (graftStructure) ->
  htmlElementFromElement(graftStructure, false)

htmlizedRoots = []
htmlElementFromElement = (element, recursive) ->
  createDomElementForElement = (element) ->
    if typeof element == 'string'
      document.createTextNode element
    else
      domElement = document.createElement element.name
      element.domElement = domElement
      updateDomElementFromElement domElement, element

  updateDomElementFromElement = (domElement, element) ->
    if 'name' in element.dirtyProperties
      createDomElementForElement element

    for attribute in element.dirtyAttributes
      domElement.setAttribute attribute, element.attributes[attribute]

    if 'children' in element.dirtyProperties
      for child, i in element.children when ! child.isDirty? || child.isDirty()
        childDomElement = htmlElementFromElement(child, true)

        if childDomElement.nodeType == Node.TEXT_NODE
          domElement.replaceChild(childDomElement, domElement.childNodes[i])
        else if ! childDomElement.parentNdoe? || childDomElement.parentNode != domElement
          domElement.appendChild childDomElement

    domElement

  if ! recursive
    htmlizedRoots.push element

  if element.domElement?
    updateDomElementFromElement element.domElement, element
  else
    createDomElementForElement element

changedRoots = []
scheduledAnimation = 0
redrawElements = ->
  htmlElementFromElement element, true for element in htmlizedRoots
  scheduledAnimation = 0

requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||
                        window.webkitRequestAnimationFrame || window.msRequestAnimationFrame ||
                        (fn) -> setTimeout fn
$(document).ready ->
  $(document).on 'element-changed', (event) ->
    for element, i in htmlizedRoots when element == event.before
      htmlizedRoots[i] = event.after

    unless scheduledAnimation
      scheduledAnimation = requestAnimationFrame redrawElements
