-- Embed the supplied script directly: Quarto 1.10's built-in Giscus template
-- does not pass through strict matching or lazy loading.
function Pandoc(doc)
  if not quarto.doc.is_format("html:js") or doc.meta.comments == false then
    return doc
  end

  -- Keep the embed outside article content so RSS feeds do not include scripts.
  quarto.doc.include_file("after-body", "../_includes/giscus.html")
  return doc
end
