import { Point3 } from "engine/math";
import { DEADZONE, Key, XboxAxis, XboxButton } from ".";
import { Gfx } from "engine";
import { Camera } from "engine/camera";
import { multiply, transformPoint, translation } from "engine/math/transform";

export class OrbitCameraController {
	disabled = false;
	bindings: Record<string, Key> = {
		'w': Key.Forward,
		'a': Key.Left,
		's': Key.Backward,
		'd': Key.Right,
		'q': Key.Down,
		'e': Key.Up,
		'shift': Key.Boost,
	};
	target: Point3 = [0, 0, 0];
	distance: number = 24;
	readonly heldKeys = new Map<Key, number>;
	readonly axis = new Map<XboxAxis, number>;
	readonly previousButtons: Record<number, number> = {};
	readonly gfx: Gfx;


	constructor(private el: HTMLElement, public camera: Camera) {
		this.gfx = camera.gfx;
		document.addEventListener('pointerlockchange', this.onPointerLockChange);
		el.addEventListener('mousedown', this.onMouseDown);
		el.addEventListener('wheel', this.onWheel);
	}

	grab() {
		this.el.requestPointerLock();
	}

	release() {
		document.exitPointerLock();
	}

	update(dt: number) {
		if (this.disabled) return;
		this.updateGamepads();

		let pitch = 0;
		let yaw = 0;
		for (const [key, value] of this.axis.entries()) {
			if (Math.abs(value) < DEADZONE) {
				continue;
			}
			switch (key) {
				case XboxAxis.RightStickX:
					yaw = value;
					break;
				case XboxAxis.RightStickY:
					pitch = value;
					break;
			}
		}
		this.camera.rotate(pitch * dt, yaw * dt);

		let transform = translation(...this.target);
		transform = multiply(transform, this.camera.rotationMatrix());
		transform = multiply(transform, translation(0, 0, -this.distance));
		this.camera.position = transformPoint(transform, [0, 1, 0]);
	}

	updateGamepads() {
		for (const pad of navigator.getGamepads()) {
			// We get nulls for some reason
			if (!pad) continue;
			const {
				axes: [leftStickX, leftStickY, rightStickX, rightStickY],
				buttons,
			} = pad;

			this.axis.set(XboxAxis.LeftStickX, leftStickX);
			this.axis.set(XboxAxis.LeftStickY, leftStickY);
			this.axis.set(XboxAxis.RightStickX, rightStickX);
			this.axis.set(XboxAxis.RightStickY, rightStickY);

			for (let i = 0; i < buttons.length; i++) {
				const button = buttons[i];
				if (this.previousButtons[i] === button.value) {
					// Value unchanged
					continue;
				}
				this.previousButtons[i] = button.value;
				if (button.value > 0.001) {
					const key = this.bindings[XboxButton[i]];
					if (key) {
						this.heldKeys.set(key, button.value);
					}
				} else {
					this.heldKeys.delete(i);
				}
			}
		}
	}

	onPointerLockChange = (_e: Event) => {
		if (this.disabled) return;
		if (document.pointerLockElement === this.el) {
			document.addEventListener('mousemove', this.onMouseMove);
		} else {
			document.removeEventListener('mousemove', this.onMouseMove);
		}
	};

	onWheel = (e: WheelEvent) => {
		if (this.disabled) return;
		this.distance *= 1.0 - (e.deltaY / -1000.0);
		this.distance = Math.min(Math.max(this.distance, 5), 200);
	};

	onMouseDown = (e: MouseEvent) => {
		if (this.disabled) return;
		// Ignore press if pointer is locked
		if (document.pointerLockElement === this.el) return;
		if (e.button === 0) {
			document.addEventListener('mouseup', this.onMouseUp);
			document.addEventListener('mousemove', this.onMouseMove);
		}
	};

	onMouseUp = (e: MouseEvent) => {
		// Ignore press if pointer is locked
		if (document.pointerLockElement === this.el) return;
		if (e.button === 0) {
			document.removeEventListener('mouseup', this.onMouseUp);
			document.removeEventListener('mousemove', this.onMouseMove);
		}
	};

	onMouseMove = (e: MouseEvent) => {
		if (this.disabled) return;
		const x = e.movementX / 1000;
		const y = e.movementY / 1000;

		this.camera.rotate(y, x);
	};
}
