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
- [ ] Load JSON
- [ ] Renderer
  - [x] Meta:Date
  - [x] Meta:Author
  - [x] Meta:Creator
  - [x] Meta:Title
  - [x] Meta:Subject
  - [x] Meta:Compression
  - [x] Meta:Encryption
  - [x] Meta:Password
  - [x] Meta:Permission
  - [ ] Page
    - [x] Background Color
    - [x] Border
    - [x] Content Size
    - [x] Padding
    - [ ] Container
      - [ ] Layout:Box
        - [ ] Alignment
        - [ ] Background Color
        - [x] Border
        - [ ] Color
        - [ ] Expanded
        - [ ] Padding
        - [x] Size
        - [ ] Child
      - [ ] Layout:Positioned Box
        - [ ] Alignment
        - [ ] Top
        - [ ] Right
        - [ ] Bottom
        - [ ] Left
        - [ ] Size
        - [ ] Child
      - [ ] Layout:Row
        - [ ] Alignment
        - [ ] Children
      - [ ] Layout:Col
        - [ ] Alignment
        - [ ] Children
      - [ ] Content:Text
        - [ ] Content
        - [ ] Color
        - [ ] Font
          - [ ] Name, EncodingName
          - [ ] TTC
          - [ ] TTF
          - [ ] Type1
        - [ ] TextSize
      - [ ] Content:Image
        - [ ] Path
        - [ ] Size

### Priority: Low

- [ ] JSON Validation
