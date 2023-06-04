# zig-pdf

## Versions

* ziglang: 0.10.1
* libHaru: 2.4.3

## Reference

* [libHaru](http://libharu.org/)
* [libHaruの部屋](http://www.t-net.ne.jp/~cyfis/libharu/)  
* [JSON Schema](https://json-schema.org/understanding-json-schema/)

## TODO

### Priority: High

- [x] JSON Schema
  - [x] Author
  - [x] Creator
  - [x] Title
  - [x] Subject
  - [x] Compression
  - [x] Encryption
  - [x] Password
  - [x] Permission
  - [x] Layout
- [ ] Load JSON (WIP)
- [x] Renderer
  - [x] Meta:Date
  - [x] Meta:Author
  - [x] Meta:Creator
  - [x] Meta:Title
  - [x] Meta:Subject
  - [x] Meta:Compression
  - [x] Meta:Encryption
  - [x] Meta:Password
  - [x] Meta:Permission
  - [x] Fonts
    - [x] Named
    - [x] TTF
    - [x] TTC
  - [x] Page
    - [x] Alignment
    - [x] Background Color
    - [x] Border
    - [x] Content Size
    - [x] Padding
    - [x] Container
      - [x] Layout:Box
        - [x] Alignment
        - [x] Background Color
        - [x] Border
        - [x] Expanded(width)
        - [x] Padding
        - [x] Size
        - [x] Child
      - [x] Layout:Positioned Box
        - [x] Top
        - [x] Right
        - [x] Bottom
        - [x] Left
        - [x] Size
        - [x] Child
      - [x] Layout:Flexible
        - [x] Flex
        - [x] Child
      - [x] Layout:Row
        - [x] Children
      - [x] Layout:Col
        - [x] Children
      - [x] Content:Text
        - [x] Content
          - [x] English
          - [x] Japanese
        - [x] Color
        - [x] Font family
        - [x] TextSize
        - [x] SoftWrap
          - [x] English
          - [x] Japanese
        - [x] WordSpace
        - [x] CharSpace
      - [x] Content:Image
        - [x] Path
          - [x] JPEG
          - [x] PNG
        - [x] Size

### Priority: Low

- [ ] JSON Validation
- [ ] Renderer
  - [ ] Page
    - [ ] Container
      - [ ] Layout:Row
        - [ ] Alignment
      - [ ] Layout:Col
        - [ ] Alignment
- [ ] Demo's JSON