import { describe, expect, it, beforeEach } from "vitest"

import XrayController from "../controllers/xray_controller"

describe("XrayController", () => {
  let controller

  beforeEach(() => {
    // test methods directly
    controller = Object.create(XrayController.prototype)
  })

  describe("highlightJSONObject", () => {
    describe("basic JSON types", () => {
      it("highlights strings", () => {
        const input = "hello world"
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string">"hello world"</span>')
      })

      it("highlights numbers", () => {
        const input = 42
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-number">42</span>')
      })

      it("highlights numbers", () => {
        const input = 4.2
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-number">4.2</span>')
      })

      it("highlights booleans", () => {
        const input = true
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-literal">true</span>')
      })

      it("highlights booleans", () => {
        const input = false
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-literal">false</span>')
      })

      it("highlights null", () => {
        const input = null
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-literal">null</span>')
      })
    })

    describe("JSON-LD keys vs strings", () => {
      it("highlights object keys", () => {
        const input = {"@context": "https://www.w3.org/ns/activitystreams"}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-key">"@context"</span>')
        expect(result).toContain('<span class="xray-json-string">"https://www.w3.org/ns/activitystreams"</span>')
      })
    })

    describe("clickable ActivityPub IDs", () => {
      it("makes valid ActivityPub IDs clickable in ID properties", () => {
        const input = {
          "actor": "https://example.com/users/alice",
          "object": "https://remote.example/notes/123",
          "inReplyTo": "https://other.example/posts/456"
        }
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string xray-json-clickable" data-id="https://example.com/users/alice">"https://example.com/users/alice"</span>')
        expect(result).toContain('<span class="xray-json-string xray-json-clickable" data-id="https://remote.example/notes/123">"https://remote.example/notes/123"</span>')
        expect(result).toContain('<span class="xray-json-string xray-json-clickable" data-id="https://other.example/posts/456">"https://other.example/posts/456"</span>')
      })

      it("does not make URLs clickable in non-ID properties", () => {
        const input = {
          "url": "https://example.com/media.jpg",
          "content": "Check out https://example.com/page",
          "name": "Alice"
        }
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string">"https://example.com/media.jpg"</span>')
        expect(result).toContain('<span class="xray-json-string">"Check out https://example.com/page"</span>')
        expect(result).not.toContain('xray-json-clickable')
      })

      it("handles nested clickable IDs", () => {
        const input = {
          "object": {
            "id": "https://example.com/notes/123",
            "attributedTo": "https://example.com/users/alice"
          }
        }
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string xray-json-clickable" data-id="https://example.com/notes/123">"https://example.com/notes/123"</span>')
        expect(result).toContain('<span class="xray-json-string xray-json-clickable" data-id="https://example.com/users/alice">"https://example.com/users/alice"</span>')
      })

      it("escapes HTML in clickable IDs", () => {
        const input = {
          "actor": "https://example.com/users/alice<script>alert('xss')</script>"
        }
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('data-id="https://example.com/users/alice&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"')
        expect(result).toContain('"https://example.com/users/alice&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"')
        expect(result).not.toContain('<script>')
      })

      it("treats @id property as clickable", () => {
        const input = {
          "@context": "https://www.w3.org/ns/activitystreams",
          "@id": "https://example.com/activities/123",
          "type": "Create"
        }
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string">"https://www.w3.org/ns/activitystreams"</span>')
        expect(result).toContain('<span class="xray-json-string xray-json-clickable" data-id="https://example.com/activities/123">"https://example.com/activities/123"</span>')
      })
    })

    describe("complex structures", () => {
      it("handles nested objects correctly", () => {
        const input = {"actor": {"type": "Person", "name": "Alice"}}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-key">"actor"</span>')
        expect(result).toContain('<span class="xray-json-key">"type"</span>')
        expect(result).toContain('<span class="xray-json-key">"name"</span>')
        expect(result).toContain('<span class="xray-json-string">"Person"</span>')
        expect(result).toContain('<span class="xray-json-string">"Alice"</span>')
      })

      it("handles arrays with mixed types", () => {
        const input = {"tags": ["hello", 42, true, null]}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-key">"tags"</span>')
        expect(result).toContain('<span class="xray-json-string">"hello"</span>')
        expect(result).toContain('<span class="xray-json-number">42</span>')
        expect(result).toContain('<span class="xray-json-literal">true</span>')
        expect(result).toContain('<span class="xray-json-literal">null</span>')
      })
    })

    describe("edge cases", () => {
      it("handles quotes in strings", () => {
        const input = {"message": 'He said "hello"'}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string">"He said &quot;hello&quot;"</span>')
      })

      it("handles numbers in various formats", () => {
        const input = {"int": 42, "float": 3.14, "negative": -1, "scientific": 1.23e-10}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-number">42</span>')
        expect(result).toContain('<span class="xray-json-number">3.14</span>')
        expect(result).toContain('<span class="xray-json-number">-1</span>')
        expect(result).toContain('<span class="xray-json-number">1.23e-10</span>')
      })

      it("doesn't highlight numbers or booleans inside strings", () => {
        const input = {"url": "https://example.com/posts/123", "note": "This is true"}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string">"https://example.com/posts/123"</span>')
        expect(result).toContain('<span class="xray-json-string">"This is true"</span>')
      })

      it("handles empty values", () => {
        const input = {"empty": "", "list": [], "obj": {}}
        const result = controller.highlightJSONObject(input)

        expect(result).toContain('<span class="xray-json-string">""</span>')
        expect(result).toContain('[]')
        expect(result).toContain('{}')
      })
    })

    describe("HTML escaping", () => {
      it("escapes HTML content in JSON string values", () => {
        const jsonObject = {
          "content": "<script>alert('xss')</script>",
          "url": "<a href=\"http://evil.com\">link</a>",
          "count": 42,
          "enabled": true,
          "metadata": null
        }
        const result = controller.highlightJSONObject(jsonObject)

        expect(result).toContain('<span class="xray-json-key">"content"</span>')
        expect(result).toContain('<span class="xray-json-key">"url"</span>')
        expect(result).toContain('<span class="xray-json-string">"&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"</span>')
        expect(result).toContain('<span class="xray-json-string">"&lt;a href=&quot;http://evil.com&quot;&gt;link&lt;/a&gt;"</span>')
        expect(result).toContain('<span class="xray-json-number">42</span>')
        expect(result).toContain('<span class="xray-json-literal">true</span>')
        expect(result).toContain('<span class="xray-json-literal">null</span>')
        expect(result).not.toContain('<script>')
        expect(result).not.toContain('<a href="http://evil.com">')
      })
    })
  })

  describe("escapeHtml", () => {
    it("escapes HTML entities", () => {
      const result = controller.escapeHtml('<script>alert("xss")</script>')

      expect(result).toBe('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(result).not.toContain('<script>')
    })

    it("handles special characters", () => {
      const result = controller.escapeHtml('&<>')

      expect(result).toBe('&amp;&lt;&gt;')
    })
  })

  describe("isIdProperty", () => {
    it("recognizes ID properties", () => {
      expect(controller.isIdProperty('id')).toBe(true)
      expect(controller.isIdProperty('@id')).toBe(true)
    })

    it("recognizes ActivityStreams object properties", () => {
      expect(controller.isIdProperty('actor')).toBe(true)
      expect(controller.isIdProperty('object')).toBe(true)
      expect(controller.isIdProperty('target')).toBe(true)
      expect(controller.isIdProperty('attributedTo')).toBe(true)
      expect(controller.isIdProperty('inReplyTo')).toBe(true)
    })

    it("recognizes collection properties", () => {
      expect(controller.isIdProperty('following')).toBe(true)
      expect(controller.isIdProperty('followers')).toBe(true)
      expect(controller.isIdProperty('inbox')).toBe(true)
      expect(controller.isIdProperty('outbox')).toBe(true)
    })

    it("rejects non-ID properties", () => {
      expect(controller.isIdProperty('content')).toBe(false)
      expect(controller.isIdProperty('name')).toBe(false)
      expect(controller.isIdProperty('published')).toBe(false)
    })

    it("rejects url property", () => {
      expect(controller.isIdProperty('url')).toBe(false)
    })
  })

  describe("isValidActivityPubId", () => {
    it("returns true for valid URLs", () => {
      expect(controller.isValidActivityPubId('https://test.example/users/alice')).toBe(true)
      expect(controller.isValidActivityPubId('https://other.example/users/bob')).toBe(true)
    })

    it("returns false for invalid URLs", () => {
      expect(controller.isValidActivityPubId('not-a-url')).toBe(false)
      expect(controller.isValidActivityPubId('ftp://example.com')).toBe(false)
      expect(controller.isValidActivityPubId('')).toBe(false)
      expect(controller.isValidActivityPubId(null)).toBe(false)
      expect(controller.isValidActivityPubId(123)).toBe(false)
    })
  })

  describe("isClickableId", () => {
    it("returns true for valid URLs in ID properties", () => {
      expect(controller.isClickableId('https://test.example/users/alice', 'actor')).toBe(true)
      expect(controller.isClickableId('https://other.example/users/bob', 'actor')).toBe(true)
      expect(controller.isClickableId('https://example.com/objects/123', 'object')).toBe(true)
      expect(controller.isClickableId('https://example.com/inbox', 'inbox')).toBe(true)
    })

    it("returns false for valid URLs in non-ID properties", () => {
      expect(controller.isClickableId('https://example.com/users/alice', 'content')).toBe(false)
      expect(controller.isClickableId('https://example.com/image.jpg', 'name')).toBe(false)
    })

    it("returns false for invalid URLs", () => {
      expect(controller.isClickableId('not-a-url', 'actor')).toBe(false)
      expect(controller.isClickableId('not-a-url', 'name')).toBe(false)
    })
  })

  describe("isLocalId", () => {
    it("identifies local IDs", () => {
      Object.defineProperty(window, 'location', {
        value: { origin: 'https://test.example' },
        writable: true
      })

      expect(controller.isLocalId('https://test.example/users/alice')).toBe(true)
      expect(controller.isLocalId('https://other.example/users/bob')).toBe(false)
      expect(controller.isLocalId('invalid-url')).toBe(false)
    })
  })
})
