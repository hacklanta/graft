window.htmlize = (graftStructure) ->
  console.log 'now we have', graftStructure
  htmlElementFromElement(graftStructure)

htmlElementFromElement = (element) ->
  if typeof element == 'string'
    document.createTextNode element
  else
    htmlElement = document.createElement element.name
    htmlElement.setAttribute attribute, value for attribute, value of element.attributes

    htmlElement.appendChild htmlElementFromElement(child) for child in element.children

    htmlElement
