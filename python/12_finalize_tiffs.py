# Save TIFFs with lossless compression and explicit resolution tags.
from pathlib import Path
from PIL import Image

Image.MAX_IMAGE_PIXELS = 150_000_000
resolutions = {"Figure_1": 1200, "Figure_2": 800, "Figure_3": 800}
for figure, resolution in resolutions.items():
    path = Path("outputs/figures") / (figure + ".tif")
    temporary = path.with_suffix(".temporary.tif")
    with Image.open(path) as image:
        image.load()
        size = image.size
        image.save(temporary, format="TIFF", compression="tiff_lzw",
                   dpi=(resolution, resolution))
    with Image.open(temporary) as image:
        if image.size != size or image.info.get("dpi") != (resolution, resolution):
            raise RuntimeError("TIFF verification failed: " + str(path))
    temporary.replace(path)
    print("Verified", path, size, resolution, "dpi")
