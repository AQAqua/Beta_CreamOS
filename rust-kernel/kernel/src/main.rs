#![no_std]
#![no_main]

use bootloader_api::{
    entry_point,
    info::{FrameBuffer, FrameBufferInfo, PixelFormat},
    BootInfo,
};
use core::panic::PanicInfo;

entry_point!(kernel_main);

fn kernel_main(boot_info: &'static mut BootInfo) -> ! {
    let Some(framebuffer) = boot_info.framebuffer.as_mut() else {
        halt();
    };
    let info = framebuffer.info();
    render(framebuffer, info)
}

fn render(framebuffer: &mut FrameBuffer, info: FrameBufferInfo) -> ! {
    let width = info.width;
    let height = info.height;
    let left_glow = Glow::new(
        width / 6,
        height / 2,
        (height / 3).max(1),
        [112, 89, 174],
        190,
    );
    let right_glow = Glow::new(
        width * 5 / 6,
        height / 3,
        (height / 4).max(1),
        [110, 177, 188],
        135,
    );
    let mut canvas = Canvas {
        pixels: framebuffer.buffer_mut(),
        info,
        left_glow,
        right_glow,
    };

    for y in 0..height {
        let gradient = (y * 100 / height.max(1)) as u8;
        for x in 0..width {
            let mut color = mix([249, 247, 241], [224, 220, 241], gradient);
            color = left_glow.apply(color, x, y);
            color = right_glow.apply(color, x, y);
            canvas.pixel(x, y, color);
        }
    }

    let panel_width = (width * 3 / 5).max(220).min(width.saturating_sub(24));
    let panel_height = (height * 2 / 5).max(180).min(height.saturating_sub(100));
    let panel_x = width.saturating_sub(panel_width) / 2;
    let panel_y = height.saturating_sub(panel_height) / 2;
    canvas.rounded_rect(
        panel_x,
        panel_y,
        panel_width,
        panel_height,
        26,
        [250, 250, 255],
        170,
    );
    canvas.rounded_rect(
        panel_x + 1,
        panel_y + 1,
        panel_width.saturating_sub(2),
        2,
        1,
        [255, 255, 255],
        220,
    );

    let scale = (width / 640).clamp(1, 3);
    canvas.text(panel_x + 28, panel_y + 34, "CREAMOS", scale, [48, 42, 67]);
    canvas.text(
        panel_x + 28,
        panel_y + 66 + 9 * scale,
        "LIQUID GLASS",
        scale,
        [82, 70, 113],
    );

    let dock_width = (width / 3).max(180).min(width.saturating_sub(24));
    let dock_height = 56.min(height);
    let dock_x = width.saturating_sub(dock_width) / 2;
    let dock_y = height.saturating_sub(dock_height + 18);
    canvas.rounded_rect(
        dock_x,
        dock_y,
        dock_width,
        dock_height,
        20,
        [250, 250, 255],
        185,
    );
    for (index, color) in [[112, 89, 174], [106, 167, 183], [224, 164, 116]]
        .into_iter()
        .enumerate()
    {
        let center_x = dock_x + dock_width * (index + 1) / 4;
        let center_y = dock_y + dock_height / 2;
        canvas.circle(center_x, center_y, 9, color);
    }

    let radius = (height / 50).clamp(8, 20).min(panel_width / 4).max(1);
    let left = panel_x + radius + 24;
    let right = panel_x + panel_width.saturating_sub(radius + 24);
    let center_y = panel_y + panel_height * 3 / 4;
    let mut center_x = left.min(right);

    loop {
        let light = Glow::new(center_x, center_y, radius, [136, 119, 198], 150);
        paint_glass_patch(&mut canvas, center_x, center_y, radius, Some(light));
        for _ in 0..80_000 {
            core::hint::spin_loop();
        }
        paint_glass_patch(&mut canvas, center_x, center_y, radius, None);
        center_x = if center_x >= right {
            left
        } else {
            center_x + 1
        };
        paint_glass_patch(&mut canvas, center_x, center_y, radius, Some(light));
    }
}

struct Canvas<'a> {
    pixels: &'a mut [u8],
    info: FrameBufferInfo,
    left_glow: Glow,
    right_glow: Glow,
}

impl Canvas<'_> {
    fn pixel(&mut self, x: usize, y: usize, color: [u8; 3]) {
        if x >= self.info.width || y >= self.info.height {
            return;
        }
        let start = (y * self.info.stride + x) * self.info.bytes_per_pixel;
        let Some(pixel) = self
            .pixels
            .get_mut(start..start + self.info.bytes_per_pixel)
        else {
            return;
        };
        match self.info.pixel_format {
            PixelFormat::Rgb => pixel[..3].copy_from_slice(&color),
            PixelFormat::Bgr => pixel[..3].copy_from_slice(&[color[2], color[1], color[0]]),
            PixelFormat::U8 => {
                pixel[0] = ((color[0] as u16 + color[1] as u16 + color[2] as u16) / 3) as u8
            }
            PixelFormat::Unknown {
                red_position,
                green_position,
                blue_position,
            } if self.info.bytes_per_pixel >= 4 => {
                let packed = ((color[0] as u32) << red_position)
                    | ((color[1] as u32) << green_position)
                    | ((color[2] as u32) << blue_position);
                pixel[..4].copy_from_slice(&packed.to_le_bytes());
            }
            PixelFormat::Unknown { .. } => {
                pixel[..3].copy_from_slice(&[color[2], color[1], color[0]])
            }
            _ => pixel[0] = ((color[0] as u16 + color[1] as u16 + color[2] as u16) / 3) as u8,
        }
    }

    fn rounded_rect(
        &mut self,
        x: usize,
        y: usize,
        width: usize,
        height: usize,
        radius: usize,
        color: [u8; 3],
        alpha: u8,
    ) {
        let right = x.saturating_add(width).min(self.info.width);
        let bottom = y.saturating_add(height).min(self.info.height);
        let radius = radius.min(width / 2).min(height / 2);

        for py in y.min(bottom)..bottom {
            for px in x.min(right)..right {
                let cx = if px < x + radius {
                    x + radius
                } else if px >= x + width.saturating_sub(radius) {
                    x + width.saturating_sub(radius + 1)
                } else {
                    px
                };
                let cy = if py < y + radius {
                    y + radius
                } else if py >= y + height.saturating_sub(radius) {
                    y + height.saturating_sub(radius + 1)
                } else {
                    py
                };
                let dx = px.abs_diff(cx);
                let dy = py.abs_diff(cy);
                if dx * dx + dy * dy <= radius * radius || radius == 0 {
                    let backdrop = self.background_at(px, py);
                    self.pixel(px, py, mix(backdrop, color, alpha));
                }
            }
        }
    }

    fn background_at(&self, x: usize, y: usize) -> [u8; 3] {
        let mut color = mix(
            [249, 247, 241],
            [224, 220, 241],
            (y * 100 / self.info.height.max(1)) as u8,
        );
        color = self.left_glow.apply(color, x, y);
        self.right_glow.apply(color, x, y)
    }

    fn circle(&mut self, cx: usize, cy: usize, radius: usize, color: [u8; 3]) {
        let radius_squared = radius * radius;
        let left = cx.saturating_sub(radius);
        let top = cy.saturating_sub(radius);
        let right = cx.saturating_add(radius).min(self.info.width);
        let bottom = cy.saturating_add(radius).min(self.info.height);

        for y in top..bottom {
            for x in left..right {
                let dx = x.abs_diff(cx);
                let dy = y.abs_diff(cy);
                if dx * dx + dy * dy <= radius_squared {
                    self.pixel(x, y, color);
                }
            }
        }
    }

    fn text(&mut self, x: usize, y: usize, text: &str, scale: usize, color: [u8; 3]) {
        let mut cursor = x;
        for character in text.bytes() {
            let rows = glyph(character);
            for (row, bits) in rows.into_iter().enumerate() {
                for column in 0..5 {
                    if bits & (1 << (4 - column)) != 0 {
                        for dy in 0..scale {
                            for dx in 0..scale {
                                self.pixel(
                                    cursor + column * scale + dx,
                                    y + row * scale + dy,
                                    color,
                                );
                            }
                        }
                    }
                }
            }
            cursor += 6 * scale;
        }
    }
}

fn paint_glass_patch(
    canvas: &mut Canvas<'_>,
    center_x: usize,
    center_y: usize,
    radius: usize,
    glow: Option<Glow>,
) {
    let left = center_x.saturating_sub(radius);
    let top = center_y.saturating_sub(radius);
    let right = center_x.saturating_add(radius).min(canvas.info.width);
    let bottom = center_y.saturating_add(radius).min(canvas.info.height);

    for y in top..bottom {
        for x in left..right {
            let backdrop = canvas.background_at(x, y);
            let surface = mix(backdrop, [250, 250, 255], 170);
            let color = glow.map_or(surface, |light| light.apply(surface, x, y));
            canvas.pixel(x, y, color);
        }
    }
}

#[derive(Clone, Copy)]
struct Glow {
    center_x: usize,
    center_y: usize,
    radius: usize,
    radius_squared: usize,
    alpha_scale: u32,
    color: [u8; 3],
}

impl Glow {
    fn new(center_x: usize, center_y: usize, radius: usize, color: [u8; 3], alpha: u8) -> Self {
        let radius = radius.max(1);
        let radius_squared = radius * radius;
        Self {
            center_x,
            center_y,
            radius,
            radius_squared,
            alpha_scale: ((alpha as u32) << 16) / radius_squared as u32,
            color,
        }
    }

    fn apply(self, base: [u8; 3], x: usize, y: usize) -> [u8; 3] {
        let dx = x.abs_diff(self.center_x);
        let dy = y.abs_diff(self.center_y);
        if dx > self.radius || dy > self.radius {
            return base;
        }
        let distance = dx * dx + dy * dy;
        if distance >= self.radius_squared {
            return base;
        }
        let alpha = (self.alpha_scale * (self.radius_squared - distance) as u32 >> 16) as u8;
        mix(base, self.color, alpha)
    }
}

fn mix(from: [u8; 3], to: [u8; 3], alpha: u8) -> [u8; 3] {
    let alpha = alpha as u16;
    let inverse = 255 - alpha;
    [
        ((from[0] as u16 * inverse + to[0] as u16 * alpha) / 255) as u8,
        ((from[1] as u16 * inverse + to[1] as u16 * alpha) / 255) as u8,
        ((from[2] as u16 * inverse + to[2] as u16 * alpha) / 255) as u8,
    ]
}

fn glyph(character: u8) -> [u8; 7] {
    match character {
        b'A' => [14, 17, 17, 31, 17, 17, 17],
        b'C' => [14, 17, 16, 16, 16, 17, 14],
        b'D' => [30, 17, 17, 17, 17, 17, 30],
        b'E' => [31, 16, 16, 30, 16, 16, 31],
        b'G' => [14, 17, 16, 23, 17, 17, 15],
        b'I' => [31, 4, 4, 4, 4, 4, 31],
        b'L' => [16, 16, 16, 16, 16, 16, 31],
        b'M' => [17, 27, 21, 21, 17, 17, 17],
        b'O' => [14, 17, 17, 17, 17, 17, 14],
        b'Q' => [14, 17, 17, 17, 21, 18, 13],
        b'R' => [30, 17, 17, 30, 20, 18, 17],
        b'S' => [15, 16, 16, 14, 1, 1, 30],
        b'U' => [17, 17, 17, 17, 17, 17, 14],
        b' ' => [0; 7],
        _ => [0; 7],
    }
}

fn halt() -> ! {
    loop {
        core::hint::spin_loop();
    }
}

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    halt()
}
