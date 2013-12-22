window.htmlize = (graftStructure) ->
  htmlElementFromElement(graftStructure)

htmlElementFromElement = (element) ->
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
