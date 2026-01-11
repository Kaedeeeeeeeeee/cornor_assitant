
import os
import json
from PIL import Image, ImageDraw

def create_icon_image(size, scale):
    # Base canvas size (logical points)
    base_size = 22
    
    # Actual pixel size
    pixel_size = int(base_size * scale)
    
    # Create transparent image
    img = Image.new('RGBA', (pixel_size, pixel_size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Settings
    # Monitor Frame
    frame_padding_x = pixel_size * 0.1
    frame_padding_y = pixel_size * 0.2
    
    frame_left = frame_padding_x
    frame_top = frame_padding_y
    frame_right = pixel_size - frame_padding_x
    frame_bottom = pixel_size - frame_padding_y
    
    frame_width = frame_right - frame_left
    frame_height = frame_bottom - frame_top
    
    stroke_width = max(1, int(1.5 * scale))
    frame_radius = 2 * scale
    
    # Draw Monitor Frame (Outline)
    draw.rounded_rectangle(
        [frame_left, frame_top, frame_right, frame_bottom],
        radius=frame_radius,
        outline=(0, 0, 0, 255),
        width=stroke_width
    )
    
    # Draw Floating "SlidePad" Window
    # User wants it in "one corner" and "small window feeling" with "distance from border"
    # Let's place it on the center-left, floating inside.
    
    # Window dimensions
    win_width = frame_width * 0.25
    win_height = frame_height * 0.6
    
    # Position: Left aligned inside, with gap using "gap_size"
    gap_size = 1.5 * scale # White space between frame and window
    
    # Calculate position
    # To be "in a corner" or "side", let's put it Middle-Left for symmetry or Bottom-Left?
    # iPad SlideOver is usually vertical centered or full height.
    # User said "small window".
    # Let's do vertically centered on the left side to mimic a slide-over panel.
    
    win_left = frame_left + stroke_width + gap_size
    win_top = frame_top + (frame_height - win_height) / 2
    
    win_right = win_left + win_width
    win_bottom = win_top + win_height
    
    win_radius = 1.5 * scale
    
    draw.rounded_rectangle(
        [win_left, win_top, win_right, win_bottom],
        radius=win_radius,
        fill=(0, 0, 0, 255)
    )

    return img

def main():
    asset_path = "/Users/user/project/slidepad/CornerAssistantApp/CornerAssistantApp/Assets.xcassets/MenuBarIcon.imageset"
    if not os.path.exists(asset_path):
        os.makedirs(asset_path)
        
    scales = {
        "icon_1x.png": 1,
        "icon_2x.png": 2,
        "icon_3x.png": 3
    }
    
    for filename, scale in scales.items():
        img = create_icon_image(22, scale) # 22pt base size
        img.save(os.path.join(asset_path, filename))
        print(f"Generated {filename}")
        
    # JSON content is already correct from previous run, but good to ensure.
    contents = {
        "images": [
            {
                "filename": "icon_1x.png",
                "idiom": "universal",
                "scale": "1x"
            },
            {
                "filename": "icon_2x.png",
                "idiom": "universal",
                "scale": "2x"
            },
            {
                "filename": "icon_3x.png",
                "idiom": "universal",
                "scale": "3x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        },
        "properties": {
            "template-rendering-intent": "template"
        }
    }
    
    with open(os.path.join(asset_path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=4)
        
if __name__ == "__main__":
    main()
