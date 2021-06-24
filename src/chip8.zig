const chip8_func = fn () void;

const assert = @import("std").debug.assert;
const info = @import("std").debug.info;
const sg = @import("sokol").gfx;
const sgl = @import("sokol").gl;
const font = @import("chip8_font.zig").fontset;

const start_address = 0x200;
const fontset_start_address = 0x50;
const display_width = 64;
const display_height = 32;

const Chip8 = struct { 
    registers: [16]u8 = undefined, 
    memory: [4096]u8 = undefined, 
    index: u16 = 0, 
    pc: u16 = 0, 
    stack: [16]u16 = undefined, 
    sp: u8 = 0, 
    delay_timer: u8 = 0, 
    sound_timer: u8 = 0, 
    keypad: [16]u8 = undefined, 
    opcode: u16 = 0, 

    table: [0xf + 1]chip8_func = undefined, 
    table_0: [0xe + 1]chip8_func = undefined, 
    table_8: [0xe + 1]chip8_func = undefined, 
    table_e: [0xe + 1]chip8_func = undefined, 
    table_f: [0x65 + 1]chip8_func = undefined, 

    display: [display_width][display_height]u32 = undefined,

    // sokol stuff
    sokol_img: sg.Image = undefined
};

var chip8: Chip8 = .{};

pub fn init() void {
    chip8 = .{ .pc = start_address };

    @memcpy(&chip8.memory[fontset_start_address], font, font.len);

    // clear the screen
    CLS_00E0();

    chip8.sokol_img = sg.makeImage(.{ .width = display_width, .height = display_height, .pixel_format = sg.PixelFormat.RGBA8, .usage = sg.Usage.DYNAMIC });

    // initialize function pointer table
    for (chip8.table) |t| t = OP_NULL;
    for (chip8.table_0) |t| t = OP_NULL;
    for (chip8.table_8) |t| t = OP_NULL;
    for (chip8.table_e) |t| t = OP_NULL;
    for (chip8.table_f) |t| t = OP_NULL;

    chip8.table[0x0] = goto_table_0;

    chip8.table[0x1] = JP_1nnn;
    chip8.table[0x2] = CALL_2nnn;
    chip8.table[0x3] = SE_3xkk;
    chip8.table[0x4] = SNE_4xkk;
    chip8.table[0x5] = SE_5xy0;
    chip8.table[0x6] = LD_6xkk;
    chip8.table[0x7] = ADD_7xkk;
    chip8.table[0x8] = goto_table_8;
    chip8.table[0x9] = SNE_9xy0;

    chip8.table[0xa] = LD_Annn;
    chip8.table[0xb] = JP_Bnnn;
    chip8.table[0xc] = RND_Cxkk;
    chip8.table[0xd] = DRW_Dxyn;
    chip8.table[0xe] = goto_table_e;
    chip8.table[0xf] = goto_table_f;

    chip8.table_0[0x0] = CLS_00E0;
    chip8.table_0[0xE] = RET_00EE;

    chip8.table_8[0x0] = LD_8xy0;
    chip8.table_8[0x1] = OR_8xy1;
    chip8.table_8[0x2] = AND_8xy2;
    chip8.table_8[0x3] = XOR_8xy3;
    chip8.table_8[0x4] = ADD_8xy4;
    chip8.table_8[0x5] = SUB_8xy5;
    chip8.table_8[0x6] = SHR_8xy6;
    chip8.table_8[0x7] = SUBN_8xy7;
    chip8.table_8[0xE] = SHL_8xyE;

    chip8.table_e[0xE] = SKP_Ex9E;
    chip8.table_e[0x1] = SKNP_ExA1;

    chip8.table_f[0x07] = LD_Fx07;
    chip8.table_f[0x0a] = LD_Fx0a;
    chip8.table_f[0x15] = LD_Fx15;
    chip8.table_f[0x18] = LD_Fx18;
    chip8.table_f[0x1e] = ADD_Fx1E;
    chip8.table_f[0x29] = LD_Fx29;
    chip8.table_f[0x33] = LD_Fx33;
    chip8.table_f[0x55] = LD_Fx55;
    chip8.table_f[0x65] = LD_Fx65;
}

pub fn loadData(buf: []u32) void {
    @memcpy(&chip8.memory[start_address], buf, buf.len);
}

pub fn loadFile() void {
    assert(false and "function not implemented");
}

pub fn update() void {
    // fetch
    chip8.opcode = (chip8.memory[chip8.pc] << 8) | chip8.memory[chip8.pc + 1];
    chip8.pc += 2;

    // decode
    // get the upper 4 bits
    var decoded: u8 = (chip8.opcode & 0xF000) >> 12;
    info("instruction [{}]", chip8.opcode);

    chip8.table[decoded]();

    if (chip8.delay_timer > 0)
        chip8.delay_timer -= 1;
    if (chip8.sound_timer > 0)
        chip8.sound_timer -= 1;
}

pub fn input() void {}

pub fn render() void {
    updateScreen();

    sgl.enableTexture();
    sgl.texture(chip8.sokol_img);

    sgl.pushMatrix();
    sgl.scale(0.75, 0.75, 1);
    sgl.beginQuads();
    sgl.v2fT2f(-1, -1, 0, 1);
    sgl.v2fT2f(-1, 1, 0, 0);
    sgl.v2fT2f(1, 1, 1, 0);
    sgl.v2fT2f(1, -1, 1, 1);
    sgl.end();
    sgl.popMatrix();
}

fn updateScreen() void {
    var img_data: sg.ImageData = .{};
    img_data.subimage[0][0] = .{ .ptr = chip8.display, .size = display_width * display_height };
    sg.updateImage(chip8.sokol_img, img_data);
}

// == goto tables =============================

fn gotoTable0() void {
    chip8.table_0[chip8.opcode & 0x000F]();
}

fn gotoTable8() void {
    chip8.table_8[chip8.opcode & 0x000F]();
}

fn gotoTableE() void {
    chip8.table_e[chip8.opcode & 0x000F]();
}

fn gotoTableF() void {
    chip8.table_f[chip8.opcode & 0x00FF]();
}

// == operations ==============================

// not yet defined
fn OP_NULL() void {
    info("operation not yet implemented");
}

// clear screen
fn CLS_00E0() void {
    @memset(chip8.display, 0x00, display_width * display_height * @sizeOf(u32));
}

// return from subroutine
fn RET_00EE() void {
    // get address at the top of the stack and jump to it
    chip8.sp -= 1;
    chip8.pc = chip8.stack[chip8.sp];
}

// jump to location nnn
fn JP_1nnn() void {
    // set program counter to nnn
    const address: u16 = chip8.opcode & 0x0FFF;
    chip8.pc = address;
}

// call subroutine at nnn
fn CALL_2nnn() void {
    // add address to the top of the stack
    const address: u16 = chip8.opcode & 0x0FFF;
    chip8.pc += 1;
    chip8.stack[chip8.sp] = chip8.pc;
    chip8.pc = address;
}

// skip next instruction if Vx == kk
fn SE_3xkk() void {
    // skip to next instruction if register Vx == kk
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const kk: u8 = chip8.opcode & 0x00FF;

    if (chip8.registers[vx] == kk)
        chip8.pc += 2;
}

// skip next instruction if Vx != kk
fn SNE_4xkk() void {
    // skip to next instruction if register Vx != kk
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const kk: u8 = chip8.opcode & 0x00FF;

    if (chip8.registers[vx] != kk)
        chip8.pc += 2;
}

// skip next instruction if Vx == Vy
fn SE_5xy0() void {
    // skip to next instruction if register Vx == register Vy
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const kk: u8 = chip8.opcode & 0x00FF;

    if (chip8.registers[vx] == chip8.registers[vy])
        chip8.pc += 2;
}

// set reg Vx to kk
fn LD_6xkk() void {
    // load value kk into register Vx
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const kk: u8 = chip8.opcode & 0x00FF;

    chip8.registers[vx] = value;
}

// Vx += kk
fn ADD_7xkk() void {
    // add kk to register Vx
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const kk: u8 = chip8.opcode & 0x00FF;

    chip8.registers[vx] += value;
}

// set Vx = Vy
fn LD_8xy0() void {
    // Vx = Vy
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[vx] = chip8.registers[vy];
}

// set Vx = Vx | Vy
fn OR_8xy1() void {
    // Vx |= Vy
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[vx] |= chip8.registers[vy];
}

// set Vx = Vx & Vy
fn AND_8xy2() void {
    // Vx &= Vy
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[vx] &= chip8.registers[vy];
}

// set Vx = Vx ^ Vy
fn XOR_8xy3() void {
    // Vx ^= Vy
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[vx] ^= chip8.registers[vy];
}

// set Vx += Vy, VF = carry
fn ADD_8xy4() void {
    // Vx += Vy, VF = carry
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    const res: u16 = chip8.registers[vx] + chip8.registers[vy];
    chip8.registers[0xF] = res > 255;
    chip8.registers[vx] = res;
}

// set Vx -= Vy, VF = NOT borrow
fn SUB_8xy5() void {
    // Vx += Vy, VF = NOT borrow
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[0xF] = chip8.registers[vx] > chip8.registers[vy];
    chip8.registers[vx] -= chip8.registers[vy];
}

// set Vx = Vx SHR 1
fn SHR_8xy6() void {
    // if Vx least significant bit is 1 then VF is set to 1,
    // otherwise it is set to 0
    // Vx is then divided by 2

    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[0xF] = chip8.registers[vx] & 0x1;
    chip8.registers[vx] >>= 1;
}

// set Vx = Vy - Vx, VF = NOT borrow
fn SUBN_8xy7() void {
    // Vx = Vy - Vx, VF = NOT borrow
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    chip8.registers[0xF] = chip8.registers[vy] > chip8.registers[vx];
    chip8.registers[vx] = chip8.registers[vy] - chip8.registers[vx];
}

// set Vx = Vx SHL 1
fn SHL_8xyE() void {
    // if Vx most significant bit is 1 then VF is set to 1,
    // otherwise it is set to 0
    // Vx is then multiplied by 2

    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;

    // set VF to the MSB
    chip8.registers[0xF] = (chip8.registers[vx] & 0x80) >> 7;
    chip8.registers[vx] <<= 1;
}

// skip next instruction if Vx != Vy
fn SNE_9xy0() void {
    // skip to next instruction if register Vx == register Vy
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;

    if (chip8.registers[vx] != chip8.registers[vy])
        chip8.pc += 2;
}

// set reg I to xxx
fn LD_Annn() void {
    // load value nnn into register I
    const value: u16 = chip8.opcode & 0x0FFF;

    chip8.index = value;
}

// jump to nnn + V0
fn JP_Bnnn() void {
    // Set program counter to nnn + V0
    const address: u16 = chip8.opcode & 0x0FFF;

    address += chip8.registers[0x0];

    chip8.pc = address;
}

// Vx = rnd & kk
fn RND_Cxkk() void {
    // set Vx to a random byte & kk
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const kk: u8 = chip8.opcode & 0x00FF;
    const rnd: u8 = (u8)(rand() % 256);

    chip8.registers[vx] = rnd & kk;
}

// display n-byte sprite starting at memory location (Vx, Vy)
fn DRW_Dxyn() void {
    // Read n bytes from memory starting at addres stored in I
    // these bytes are then displayed as sprites on screen at coordinates
    // stored in registers vx and vy, the coordinates wrap
    // sprites are XORed onto the display, if this causes any pixels
    // to be eares VF is set to 1, otherwise to 0
    // the sprite is guaranteed to be 8 pixels wide

    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const vy: u8 = (chip8.opcode & 0x00F0) >> 4;
    const height: u8 = chip8.opcode & 0x000F;

    const x: u8 = chip8.registers[vx];
    const y: u8 = chip8.registers[vy];

    chip8.registers[0xF] = 0;

    var row: u8 = 0;

    while (row < height) : (row += 1) {
        var column: u8 = 0;
        const sprite_byte: u8 = chip8.memory[chip8.index + row];
        while (column < 8) : (column += 1) {
            const sprite_px: u8 = sprite_byte & (0x80 >> column);
            const xpos: u8 = (x + column) % display_width;
            const ypos: u8 = (y + row) % display_height;
            const screen_px: *u32 = &chip8.display[ypos][xpos];

            // if this is a sprite pixel
            if (sprite_px != 0) {
                // if the same pixel is already on, set the
                // VF register to 1
                if (screen_px.* != 0)
                    chip8.registers[0xF] = 1;

                // XOR pixel
                screen_px.* ^= 0xFFFFFFFF;
            }
        }
    }
}

// skip next instruction if key with the value of Vx is pressed
fn SKP_Ex9E() void {
    // pc += 2 if key Vx is pressed
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;

    if (chip8.keypad[chip8.registers[vx]])
        chip8.pc += 2;
}

// skip next instruction if key with the value of Vx is not pressed
fn SKNP_ExA1() void {
    // pc += 2 if key Vx is NOT pressed
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;

    if (!chip8.keypad[chip8.registers[vx]])
        chip8.pc += 2;
}

// set Vx = delay timer
fn LD_Fx07() void {
    // Vx = delay timer
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    chip8.registers[vx] = chip8.delay_timer;
}

// wait for a key press, store value of key in Vx
fn LD_Fx0a() void {
    // wait for a key to be pressed (by decreasing pc)
    // the value of the key is stored in Vx

    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;

    var i: u8 = 0;
    while (i < 16) : (i += 1) {
        if (chip8.keypad[i]) {
            chip8.registers[vx] = i;
            return;
        }
    }

    chip8.pc -= 2;
}

// set delay timer = Vx
fn LD_Fx15() void {
    // delay timer = Vx
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    chip8.delay_timer = vx;
}

// set sound timer = Vx
fn LD_Fx18() void {
    // sound timer = Vx
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    chip8.sound_timer = chip8.registers[vx];
}

// set I += Vx
fn ADD_Fx1E() void {
    // register I += Vx
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    chip8.index += vx;
}

// set I = location of sprite for digit Vx
fn LD_Fx29() void {
    // returns position in memory of digit Vx from font
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const digit: u8 = chip8.registers[vx];

    chip8.index = fontset_start_address + (5 * digit);
}

// store BCD representation of Vx in memory location I, I+1, I+2
fn LD_Fx33() void {
    // store in BCD representation value of Vx in
    // memory in I, I+1 and I+2.
    // BCD means:
    // value = 154
    // mem[i+0] = 1 -> [1]54
    // mem[i+1] = 5 -> 1[5]4
    // mem[i+2] = 4 -> 15[4]

    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;
    const value: u8 = chip8.registers[vx];

    chip8.memory[chip8.index + 2] = value % 10;
    value /= 10;

    chip8.memory[chip8.index + 1] = value % 10;
    value /= 10;

    chip8.memory[chip8.index] = value % 10;
}

// store registers V0 to Vx in memory starting at location I
fn LD_Fx55() void {
    // store register from V0 to Vx in memory from I
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;

    var i: u8 = 0;
    while (i < vx) : (i += 1) {
        chip8.memory[chip8.index + i] = chip8.registers[i];
    }
}

// read registers V0 to Vx in memory starting at location I
fn LD_Fx65() void {
    // read memory from i in registers V0 to Vx
    const vx: u8 = (chip8.opcode & 0x0F00) >> 8;

    while (i < vx) : (i += 1) {
        chip8.registers[i] = chip8.memory[chip8.index + i];
    }
}
