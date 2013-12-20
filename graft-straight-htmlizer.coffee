window.htmlize = (graftStructure) ->
  htmlElementFromElement(graftStructure)

htmlElementFromElement = (element) ->
  createDomElementForElement = (element) ->
    if typeof element == 'string'
      document.createTextNode element
    else
      domElement = document.createElement element.name
      updateDomElementFromElement domElement, element

  updateDomElementFromElement = (domElement, element) ->
    if domElement.nodeName.toLowerCase() != element.name.toLowerCase()
      createDomElementForElement element

    domElement.setAttribute attribute, value for attribute, value of element.attributes
    for child, i in element.children
      childDomElement = htmlElementFromElement(child) 
      if childDomElement.nodeType == Node.TEXT_NODE
        domElement.replaceChild(childDomElement, domElement.childNodes[i])
      else if ! childDomElement.parentNdoe? || childDomElement.parentNode != domElement
        domElement.appendChild childDomElement

    domElement

  if element.domElement?
    updateDomElementFromElement element.domElement, element
  else
    createDomElementForElement element
