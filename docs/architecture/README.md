# Architecture figures

The six `.dot` files are the authoritative diagram sources. Render with Graphviz:

```sh
for source in docs/architecture/*.dot; do
  dot -Tsvg "$source" -o "docs/src/assets/architecture/$(basename "$source" .dot).svg"
done
```

The manual includes the resulting SVGs. This audit rendered with Graphviz through
`@viz-js/viz` 3.25.0 and inspected raster previews. The diagrams describe verified
source relationships. Grouped boxes abbreviate types; internal names do not
become stable extension APIs. Update source and rendered figure together.
