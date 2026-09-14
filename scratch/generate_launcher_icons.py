import os
from PIL import Image, ImageDraw

def create_doseband_launcher_icons():
    output_dir = r"c:\Users\Bisht\OneDrive\Desktop\doseband\flutter_app\assets\icon"
    os.makedirs(output_dir, exist_ok=True)

    SIZE_4X = 4096
    CANVAS_SIZE = 1024

    SAFETY_ORANGE = (234, 88, 12, 255)     # #EA580C
    WHITE = (255, 255, 255, 255)
    TRANSPARENT = (0, 0, 0, 0)

    def generate_symbol_image(size, is_adaptive_foreground=False):
        img = Image.new("RGBA", (size, size), TRANSPARENT)
        draw = ImageDraw.Draw(img)

        cx, cy = size // 2, size // 2
        height = int(size * 0.52) if is_adaptive_foreground else int(size * 0.58)

        sw = int(height * 0.82)
        top_y = cy - int(height * 0.48)
        bot_y = cy + int(height * 0.52)

        left_x = cx - sw // 2
        right_x = cx + sw // 2
        dip_y = top_y + int(height * 0.06)

        shield_pts = []
        steps = 30
        for i in range(steps + 1):
            t = i / steps
            x = (1 - t)**2 * left_x + 2 * (1 - t) * t * (left_x + (cx - left_x) * 0.5) + t**2 * cx
            y = (1 - t)**2 * top_y + 2 * (1 - t) * t * top_y + t**2 * dip_y
            shield_pts.append((x, y))

        for i in range(1, steps + 1):
            t = i / steps
            x = (1 - t)**2 * cx + 2 * (1 - t) * t * (cx + (right_x - cx) * 0.5) + t**2 * right_x
            y = (1 - t)**2 * dip_y + 2 * (1 - t) * t * top_y + t**2 * top_y
            shield_pts.append((x, y))

        for i in range(1, steps + 1):
            t = i / steps
            x = (1 - t)**2 * right_x + 2 * (1 - t) * t * right_x + t**2 * cx
            y = (1 - t)**2 * top_y + 2 * (1 - t) * t * (top_y + (bot_y - top_y) * 0.65) + t**2 * bot_y
            shield_pts.append((x, y))

        for i in range(1, steps + 1):
            t = i / steps
            x = (1 - t)**2 * cx + 2 * (1 - t) * t * left_x + t**2 * left_x
            y = (1 - t)**2 * bot_y + 2 * (1 - t) * t * (top_y + (bot_y - top_y) * 0.65) + t**2 * top_y
            shield_pts.append((x, y))

        draw.polygon(shield_pts, fill=WHITE)

        band_w = int(height * 0.18)
        band_h = int(height * 0.52)
        band_left = cx - band_w // 2
        band_top = cy - band_h // 2
        
        dial_r = int(height * 0.22)
        bezel_r = int(height * 0.18)
        lens_r = int(height * 0.14)
        dot_r = int(height * 0.05)

        cutout_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        cdraw = ImageDraw.Draw(cutout_img)

        cdraw.rounded_rectangle(
            [band_left, band_top, band_left + band_w, band_top + band_h],
            radius=int(band_w * 0.35),
            fill=WHITE
        )
        cdraw.ellipse(
            [cx - dial_r, cy - dial_r, cx + dial_r, cy + dial_r],
            fill=WHITE
        )

        cdraw.ellipse(
            [cx - bezel_r, cy - bezel_r, cx + bezel_r, cy + bezel_r],
            fill=TRANSPARENT
        )

        cdraw.ellipse(
            [cx - lens_r, cy - lens_r, cx + lens_r, cy + lens_r],
            fill=WHITE
        )

        cdraw.ellipse(
            [cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r],
            fill=TRANSPARENT
        )

        img_pixels = img.load()
        cut_pixels = cutout_img.load()
        for y in range(size):
            for x in range(size):
                if cut_pixels[x, y][3] > 0:
                    if is_adaptive_foreground:
                        img_pixels[x, y] = (0, 0, 0, 0)
                    else:
                        img_pixels[x, y] = SAFETY_ORANGE

        notch_w = int(band_w * 0.6)
        notch_h = int(height * 0.02)
        notch_x = cx - notch_w // 2

        draw.rounded_rectangle(
            [notch_x, cy - int(height * 0.21), notch_x + notch_w, cy - int(height * 0.21) + notch_h],
            radius=int(notch_h * 0.5),
            fill=WHITE
        )
        draw.rounded_rectangle(
            [notch_x, cy + int(height * 0.19), notch_x + notch_w, cy + int(height * 0.19) + notch_h],
            radius=int(notch_h * 0.5),
            fill=WHITE
        )

        return img

    fg_4x = generate_symbol_image(SIZE_4X, is_adaptive_foreground=True)
    fg_1024 = fg_4x.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
    fg_path = os.path.join(output_dir, "doseband_foreground.png")
    fg_1024.save(fg_path, "PNG")
    print(f"Saved: {fg_path}")

    legacy_4x = Image.new("RGBA", (SIZE_4X, SIZE_4X), SAFETY_ORANGE)
    symbol_img = generate_symbol_image(SIZE_4X, is_adaptive_foreground=False)
    legacy_4x.alpha_composite(symbol_img)
    
    legacy_1024 = legacy_4x.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
    legacy_path = os.path.join(output_dir, "doseband_icon.png")
    legacy_1024.save(legacy_path, "PNG")
    print(f"Saved: {legacy_path}")

if __name__ == "__main__":
    create_doseband_launcher_icons()
