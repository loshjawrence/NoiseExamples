import {vec4, mat4} from 'gl-matrix';
import Drawable from './Drawable';
import {gl} from '../../globals';

var activeProgram: WebGLProgram = null;

export class Shader {
  shader: WebGLShader;

  constructor(type: number, source: string) {
    this.shader = gl.createShader(type);
    gl.shaderSource(this.shader, source);
    gl.compileShader(this.shader);

    if (!gl.getShaderParameter(this.shader, gl.COMPILE_STATUS)) {
      throw gl.getShaderInfoLog(this.shader);
    }
  }
};

class ShaderProgram {
  prog: WebGLProgram;

  attrPos: number;

  unifView: WebGLUniformLocation;
  unifCamToWorld: WebGLUniformLocation;
  unifTime: WebGLUniformLocation;
  unifScreenWidth: WebGLUniformLocation;
  unifScreenHeight: WebGLUniformLocation;
  unifPixelLenX: WebGLUniformLocation;
  unifPixelLenY: WebGLUniformLocation;

  constructor(shaders: Array<Shader>) {
    this.prog = gl.createProgram();

    for (let shader of shaders) {
      gl.attachShader(this.prog, shader.shader);
    }
    gl.linkProgram(this.prog);
    if (!gl.getProgramParameter(this.prog, gl.LINK_STATUS)) {
      throw gl.getProgramInfoLog(this.prog);
    }

    // Raymarcher only draws a quad in screen space! No other attributes
    this.attrPos = gl.getAttribLocation(this.prog, "vs_Pos");

    // TODO: add other attributes here
    this.unifView   = gl.getUniformLocation(this.prog, "u_View");
    this.unifCamToWorld   = gl.getUniformLocation(this.prog, "u_CamToWorld");
    this.unifTime   = gl.getUniformLocation(this.prog, "u_Time");
    this.unifScreenWidth   = gl.getUniformLocation(this.prog, "u_ScreenWidth");
    this.unifScreenHeight   = gl.getUniformLocation(this.prog, "u_ScreenHeight");
    this.unifPixelLenX   = gl.getUniformLocation(this.prog, "u_PixelLenX");
    this.unifPixelLenY   = gl.getUniformLocation(this.prog, "u_PixelLenY");
  }

  use() {
    if (activeProgram !== this.prog) {
      gl.useProgram(this.prog);
      activeProgram = this.prog;
    }
  }

  // TODO: add functions to modify uniforms
  setViewMatrix(view: mat4) {
    this.use();
    if (this.unifView !== -1) {
      gl.uniformMatrix4fv(this.unifView, false, view);
    }
  }

  setCamToWorldMatrix(camToWorld: mat4) {
    this.use();
    if (this.unifCamToWorld !== -1) {
      gl.uniformMatrix4fv(this.unifCamToWorld, false, camToWorld);
    }
  }
  setScreenWidth(screenWidth: number) {
    this.use();
    if (this.unifScreenWidth !== -1) {
      gl.uniform1f(this.unifScreenWidth, screenWidth);
    }
  }
  setScreenHeight(screenHeight: number) {
    this.use();
    if (this.unifScreenHeight !== -1) {
      gl.uniform1f(this.unifScreenHeight, screenHeight);
    }
  }
  setPixelLenX(pixelLenX: number) {
    this.use();
    if (this.unifPixelLenX !== -1) {
      gl.uniform1f(this.unifPixelLenX, pixelLenX);
    }
  }
  setPixelLenY(pixelLenY: number) {
    this.use();
    if (this.unifPixelLenY !== -1) {
      gl.uniform1f(this.unifPixelLenY, pixelLenY);
    }
  }

  setTime() {
    this.use();
    if (this.unifTime !== -1) {
      const timeWarp = 2.0;
      gl.uniform1f(this.unifTime, performance.now() * (1.0 / (1000.0 * timeWarp)));
    }
  }


  draw(d: Drawable) {
    this.use();

    if (this.attrPos != -1 && d.bindPos()) {
      gl.enableVertexAttribArray(this.attrPos);
      gl.vertexAttribPointer(this.attrPos, 4, gl.FLOAT, false, 0, 0);
    }

    d.bindIdx();
    gl.drawElements(d.drawMode(), d.elemCount(), gl.UNSIGNED_INT, 0);

    if (this.attrPos != -1) gl.disableVertexAttribArray(this.attrPos);

  }
};

export default ShaderProgram;
