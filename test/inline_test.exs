defmodule CvBuilder.InlineTest do
  use ExUnit.Case, async: true

  alias CvBuilder.Inline

  doctest CvBuilder.Inline

  describe "escapen" do
    test "amperstand" do
      assert Inline.render("R&D") == "R&amp;D"
    end

    test "html in de tekst wordt onschadelijk gemaakt" do
      assert Inline.render("<script>alert(1)</script>") == "&lt;script&gt;alert(1)&lt;/script&gt;"
    end

    test "aanhalingstekens" do
      assert Inline.render(~s(quote " en ')) == "quote &quot; en &#39;"
    end
  end

  describe "opmaak binnen een blok" do
    test "vet met twee sterretjes" do
      assert Inline.render("**vet**") == "<strong>vet</strong>"
    end

    test "vet met twee liggende streepjes" do
      assert Inline.render("__vet__") == "<strong>vet</strong>"
    end

    test "cursief" do
      assert Inline.render("*cursief*") == "<em>cursief</em>"
      assert Inline.render("_cursief_") == "<em>cursief</em>"
    end

    test "code" do
      assert Inline.render("`C#`") == "<code>C#</code>"
    end

    test "doorhalen" do
      assert Inline.render("~~weg~~") == "<del>weg</del>"
    end

    test "vet blijft vet en wordt niet eerst cursief" do
      assert Inline.render("**vet**") == "<strong>vet</strong>"
    end

    test "meerdere vette woorden" do
      assert Inline.render("**een** en **twee**") ==
               "<strong>een</strong> en <strong>twee</strong>"
    end

    test "een underscore in een variabelenaam blijft een underscore" do
      assert Inline.render("my_var_name") == "my_var_name"
    end

    test "link met tekst" do
      assert Inline.render("[GitHub](https://github.com/jouw-handle)") ==
               ~s(<a href="https://github.com/jouw-handle">GitHub</a>)
    end

    test "de url in een link wordt niet opnieuw gelinkt" do
      html = Inline.render("[GitHub](https://github.com/jouw-handle)")

      assert length(String.split(html, "<a ")) == 2
    end

    test "javascript-urls worden geneutraliseerd" do
      assert Inline.render("[klik](javascript:alert)") == ~s(<a href="#">klik</a>)
    end
  end

  describe "automatische links" do
    test "een kale url wordt klikbaar" do
      assert Inline.render("zie https://example.com") ==
               ~s(zie <a href="https://example.com" rel="noopener">https://example.com</a>)
    end

    test "afsluitende punt hoort niet bij de link" do
      assert Inline.render("zie https://example.com.") ==
               ~s(zie <a href="https://example.com" rel="noopener">https://example.com</a>.)
    end

    test "een kaal e-mailadres wordt een mailto-link" do
      assert Inline.render("jan@voorbeeld.nl") ==
               ~s(<a href="mailto:jan@voorbeeld.nl">jan@voorbeeld.nl</a>)
    end

    test "html wordt eerst ge-escaped en daarna opgemaakt" do
      assert Inline.render("**Laravel & PHP**") == "<strong>Laravel &amp; PHP</strong>"
    end
  end

  describe "attributen" do
    test "escapet dubbele aanhalingstekens" do
      assert Inline.escape_attr(~s(a "b" c)) == "a &quot;b&quot; c"
    end
  end
end
