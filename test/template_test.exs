defmodule CvBuilder.TemplateTest do
  use ExUnit.Case, async: true

  alias CvBuilder.{Config, Template}

  test "de pagina heeft een doctype en een head" do
    html = Template.wrap("<p>inhoud</p>")

    assert String.starts_with?(html, "<!DOCTYPE html>")
    assert html =~ "<title>CV</title>"
    assert html =~ "<p>inhoud</p>"
  end

  test "de taal komt uit de configuratie" do
    assert Template.wrap("x", "CV", %Config{lang: "en"}) =~ ~s(<html lang="en">)
  end

  test "de accentkleur komt in de stylesheet" do
    html = Template.wrap("x", "CV", %Config{accent: "#0f766e"})

    assert html =~ "--accent: #0f766e;"
  end

  test "de printstylesheet staat erin" do
    html = Template.wrap("x")

    assert html =~ "@page"
    assert html =~ "size: A4"
    assert html =~ "break-inside: avoid"
    assert html =~ "print-color-adjust: exact"
  end

  test "de body staat in een main-element" do
    assert Template.wrap("x") =~ ~s(<main class="page">)
  end
end
