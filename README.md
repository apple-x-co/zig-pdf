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
    - [x] Alignment
    - [x] Background Color
    - [x] Border
    - [x] Content Size
    - [x] Padding
    - [ ] Container
      - [ ] Layout:Box
        - [ ] Alignment *(later)*
        - [x] Background Color
        - [x] Border
        - [x] Expanded(width)
        - [x] Padding
        - [x] Size
        - [ ] Child *(later)*
          - "depends on itself" エラーが起きる
          - "anyopaque" を使えないか?
          - 後で実装する
      - [ ] Layout:Positioned Box
        - [ ] Alignment *(later)*
        - [x] Top
        - [x] Right
        - [x] Bottom
        - [x] Left
        - [x] Size
        - [ ] Child *(later)*
      - [ ] Layout:Row
        - [ ] Alignment
        - [ ] Children
      - [ ] Layout:Col
        - [ ] Alignment
        - [ ] Children
      - [ ] Content:Text
        - [x] Content
        - [x] Color
        - [ ] Font
          - [ ] Name, EncodingName
          - [ ] TTC
          - [ ] TTF
          - [ ] Type1
        - [x] TextSize
        - [ ] MaxLines
        - [ ] SoftWrap
      - [x] Content:Image
        - [x] Path
          - [x] JPEG
          - [x] PNG
        - [x] Size

### Priority: Low

- [ ] JSON Validation
- [ ] libharu's demo