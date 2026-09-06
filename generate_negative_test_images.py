"""
DoseBand Negative Test Image Generator.

Generates programmatically synthesized negative test cases to verify that
the Test-Strip Validator strictly rejects invalid, uncalibrated, or unrelated images.
"""

import os
import cv2
import numpy as np

OUTPUT_DIR = "test_images"


def generate_negative_benchmarks():
    """Generates all 8 negative test image assets."""
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    width, height = 720, 480
    font = cv2.FONT_HERSHEY_SIMPLEX

    # 1. Plain white paper
    white_img = np.full((height, width, 3), 250, dtype=np.uint8)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_plain_white.jpg"), white_img)

    # 2. Plain grey paper
    grey_img = np.full((height, width, 3), 130, dtype=np.uint8)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_plain_grey.jpg"), grey_img)

    # 3. Black rectangle / pitch dark image
    black_img = np.full((height, width, 3), 20, dtype=np.uint8)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_black_rectangle.jpg"), black_img)

    # 4. Random colored patches (Vivid non-chemical colors: red, blue, green, yellow)
    color_img = np.full((height, width, 3), 240, dtype=np.uint8)
    colors = [(0, 0, 230), (230, 0, 0), (0, 200, 0), (0, 220, 220)]
    for i, c in enumerate(colors):
        x1 = 50 + i * 160
        cv2.rectangle(color_img, (x1, 100), (x1 + 140, 380), c, -1)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_colored_rectangles.jpg"), color_img)

    # 5. Smooth color gradient (Rainbow/sunset gradient)
    grad_img = np.zeros((height, width, 3), dtype=np.uint8)
    for x in range(width):
        r = int(255 * (x / width))
        g = int(255 * (1.0 - abs(x - width/2) / (width/2)))
        b = int(255 * (1.0 - x / width))
        grad_img[:, x] = (b, g, r)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_gradient.jpg"), grad_img)

    # 6. Noisy / textured wall / skin / fabric pattern
    np.random.seed(42)
    noise = np.random.normal(128, 45, (height, width, 3)).clip(0, 255).astype(np.uint8)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_noisy_texture.jpg"), noise)

    # 7. Screenshot / Document with lots of text & UI buttons (High edge density)
    doc_img = np.full((height, width, 3), 255, dtype=np.uint8)
    # Draw mock UI header
    cv2.rectangle(doc_img, (0, 0), (width, 50), (200, 100, 50), -1)
    cv2.putText(doc_img, "Web Browser - Email Inbox Screenshot", (20, 32), font, 0.7, (255, 255, 255), 2)
    for line_idx in range(12):
        y = 90 + line_idx * 30
        cv2.putText(doc_img, f"Line {line_idx+1}: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod.", (30, y), font, 0.45, (30, 30, 30), 1)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_screenshot_text.jpg"), doc_img)

    # 8. Cropped H2S patch without reference scale (Just an isolated dark grey square in the center)
    isolated_patch = np.full((height, width, 3), 245, dtype=np.uint8)
    # Draw only a dark grey box in center with no reference scale
    cv2.rectangle(isolated_patch, (250, 150), (480, 320), (80, 80, 80), -1)
    cv2.putText(isolated_patch, "DARK GREY SWATCH", (270, 240), font, 0.5, (255, 255, 255), 1)
    cv2.imwrite(os.path.join(OUTPUT_DIR, "negative_isolated_h2s_crop.jpg"), isolated_patch)

    print("[OK] Generated all 8 programmatic negative benchmark images in 'test_images/'.")


if __name__ == "__main__":
    generate_negative_benchmarks()
