// Original art direction; no downloaded textures, models or reference-game code.
export const INK_COLORS = Object.freeze({
  skin: 0xc7bfa9, hair: 0x202e30, coat: 0x657d79, dark: 0x283b3c,
  trim: 0xc7a66b, scarf: 0xb36b45, boot: 0x354143, white: 0xe6dfc9,
  eye: 0x101e22, wood: 0x7c8070, pale: 0xc0baa4, sea: 0x566f70,
});
export const INK_BANDS = Object.freeze([70, 155, 235]);
export function artDirection(ink = false) {
  return ink ? {
    ink: true, background: 0xdedacb, fogNear: 10, fogFar: 29,
    sky: 0xffffff, ground: 0x5c6660, ambient: 1.2,
    sun: 0xffedd0, sunPower: 1.5, rim: 0xc4d4cf, rimPower: .6,
    water: 0x7c9390, exposure: 1,
  } : {
    ink: false, background: null, fogNear: 11, fogFar: 35,
    sky: 0xc2efff, ground: 0x4b4b3a, ambient: 2.5,
    sun: 0xffd3a1, sunPower: 3.4, rim: 0x77dcd4, rimPower: 2,
    water: 0x185568, exposure: 1.3,
  };
}
