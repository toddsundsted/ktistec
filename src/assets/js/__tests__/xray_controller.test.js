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
})
