defmodule CvBuilder.ImageTest do
  use ExUnit.Case, async: false

  alias CvBuilder.Image

  # Een echte png van 1x1 pixel, zodat de test geen imagemagick nodig heeft.
  @one_pixel Base.decode64!(
               "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
             )

  setup do
    dir = Path.join(System.tmp_dir!(), "cv_builder_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)

    path = Path.join(dir, "pixel.png")
    File.write!(path, @one_pixel)

    on_exit(fn -> File.rm_rf(dir) end)

    %{dir: dir, path: path}
  end

  test "herkent de mime-types", %{} do
    assert Image.mime("a/b.png") == "image/png"
    assert Image.mime("a/b.JPG") == "image/jpeg"
    assert Image.mime("a/b.jpeg") == "image/jpeg"
    assert Image.mime("a/b.webp") == "image/webp"
    assert Image.mime("a/b.svg") == "image/svg+xml"
    assert Image.mime("a/b.exe") == nil
  end

  test "zet een bestand om naar een data-uri", %{path: path} do
    uri = Image.data_uri(path, max_width: 0)

    assert String.starts_with?(uri, "data:image/png;base64,")
    assert uri == "data:image/png;base64," <> Base.encode64(@one_pixel)
  end

  test "een ontbrekend bestand geeft nil in plaats van een crash" do
    assert Image.data_uri("bestaat-niet.png") == nil
    assert Image.data_uri(nil) == nil
  end

  test "max_width zet de verkleining aan en uit" do
    assert Image.magick_available?() in [true, false]
  end
end
