# TODO

1. Need to make it so "monolithized" links can still be linked to. E.g.
```markdown
> TOC.md
# TOC

- [First Link](FirstLink.md)
- [Second Link](SecondLink.md)
```
```md
> FirstLink.md
# First Link

Some content here.
```
```md
> SecondLink.md
# Second Link

A reference to [First Link](FirstLink.md).
```

When monolithizing `TOC.md`, the link in `SecondLink.md` should still work, and ideally it is converted to `[First Link](#first_link)` or something similar in the monolithized output.