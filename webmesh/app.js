"use strict";

var canvas = document.getElementById("glcanvas");
var message = document.getElementById("message");
var gl = canvas.getContext("webgl2");

function showError(text) {
    message.textContent = text;
    message.style.color = "#ff9b9b";
}

if (!gl) {
    showError("WebGL2 недоступен в этом браузере");
    throw new Error("WebGL2 is not available");
}

var vertexShaderSource = `#version 300 es
in vec3 aPosition;
in vec3 aNormal;
in vec2 aTexCoord;

uniform mat4 uModel;
uniform mat4 uView;
uniform mat4 uProjection;

out vec3 vNormal;
out vec2 vTexCoord;

void main() {
    vec4 worldPosition = uModel * vec4(aPosition, 1.0);
    gl_Position = uProjection * uView * worldPosition;
    vNormal = mat3(uModel) * aNormal;
    vTexCoord = aTexCoord;
}
`;

var fragmentShaderSource = `#version 300 es
precision mediump float;

in vec3 vNormal;
in vec2 vTexCoord;

uniform sampler2D uTexture;
uniform vec3 uLightDirection;

out vec4 outColor;

void main() {
    vec3 normal = normalize(vNormal);
    vec3 lightDirection = normalize(uLightDirection);
    float diffuse = max(dot(normal, lightDirection), 0.0);
    float light = 0.25 + diffuse * 0.75;
    vec4 textureColor = texture(uTexture, vTexCoord);
    outColor = vec4(textureColor.rgb * light, textureColor.a);
}
`;

function createShader(type, source) {
    var shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
        var error = gl.getShaderInfoLog(shader);
        gl.deleteShader(shader);
        showError("Ошибка компиляции шейдера");
        throw new Error(error);
    }

    return shader;
}

function createProgram() {
    var vertexShader = createShader(gl.VERTEX_SHADER, vertexShaderSource);
    var fragmentShader = createShader(gl.FRAGMENT_SHADER, fragmentShaderSource);
    var program = gl.createProgram();

    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    gl.deleteShader(vertexShader);
    gl.deleteShader(fragmentShader);

    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
        var error = gl.getProgramInfoLog(program);
        gl.deleteProgram(program);
        showError("Ошибка связывания шейдеров");
        throw new Error(error);
    }

    return program;
}

function createPerspective(fieldOfView, aspect, near, far) {
    var f = 1.0 / Math.tan(fieldOfView / 2.0);
    var range = 1.0 / (near - far);

    return new Float32Array([
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (near + far) * range, -1,
        0, 0, 2 * near * far * range, 0
    ]);
}

var viewMatrix = new Float32Array([
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, -6, 1
]);

function createModel(rotationX, rotationY) {
    var cx = Math.cos(rotationX);
    var sx = Math.sin(rotationX);
    var cy = Math.cos(rotationY);
    var sy = Math.sin(rotationY);

    return new Float32Array([
        cy, sx * sy, -cx * sy, 0,
        0, cx, sx, 0,
        sy, -sx * cy, cx * cy, 0,
        0, 0, 0, 1
    ]);
}

var program = createProgram();
gl.useProgram(program);

var positionLocation = gl.getAttribLocation(program, "aPosition");
var normalLocation = gl.getAttribLocation(program, "aNormal");
var texCoordLocation = gl.getAttribLocation(program, "aTexCoord");

var modelLocation = gl.getUniformLocation(program, "uModel");
var viewLocation = gl.getUniformLocation(program, "uView");
var projectionLocation = gl.getUniformLocation(program, "uProjection");
var textureLocation = gl.getUniformLocation(program, "uTexture");
var lightDirectionLocation = gl.getUniformLocation(program, "uLightDirection");

var vertices = new Float32Array([]);

var vertexBuffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.DYNAMIC_DRAW);

var vertexArray = gl.createVertexArray();
gl.bindVertexArray(vertexArray);

var stride = 8 * 4;

gl.enableVertexAttribArray(positionLocation);
gl.vertexAttribPointer(positionLocation, 3, gl.FLOAT, false, stride, 0);

gl.enableVertexAttribArray(normalLocation);
gl.vertexAttribPointer(normalLocation, 3, gl.FLOAT, false, stride, 3 * 4);

gl.enableVertexAttribArray(texCoordLocation);
gl.vertexAttribPointer(texCoordLocation, 2, gl.FLOAT, false, stride, 6 * 4);

var texturePixels = new Uint8Array([
    237, 242, 247, 255,   65, 125, 190, 255,
     65, 125, 190, 255,  237, 242, 247, 255
]);

var texture = gl.createTexture();
gl.activeTexture(gl.TEXTURE0);
gl.bindTexture(gl.TEXTURE_2D, texture);
gl.texImage2D(
    gl.TEXTURE_2D,
    0,
    gl.RGBA,
    2,
    2,
    0,
    gl.RGBA,
    gl.UNSIGNED_BYTE,
    texturePixels
);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);

gl.uniform1i(textureLocation, 0);
gl.uniform3f(lightDirectionLocation, 0.4, 0.7, 0.6);
gl.uniformMatrix4fv(viewLocation, false, viewMatrix);

gl.enable(gl.DEPTH_TEST);
gl.enable(gl.CULL_FACE);
gl.cullFace(gl.BACK);
gl.clearColor(0.07, 0.09, 0.13, 1.0);

var rotationX = 0.45;
var rotationY = 0.0;
var previousTime = 0;
var vertexCount = vertices.length / 8;

function render(time) {
    var delta = 0.0;

    if (previousTime !== 0) {
        delta = (time - previousTime) * 0.001;
    }

    previousTime = time;
    rotationY += delta * 0.7;

    var scale = window.devicePixelRatio || 1;
    var width = Math.floor(canvas.clientWidth * scale);
    var height = Math.floor(canvas.clientHeight * scale);

    if (canvas.width !== width || canvas.height !== height) {
        canvas.width = width;
        canvas.height = height;
    }

    gl.viewport(0, 0, width, height);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

    var aspect = canvas.width / canvas.height;
    var projection = createPerspective(Math.PI / 4, aspect, 0.1, 100.0);
    var model = createModel(rotationX, rotationY);

    gl.uniformMatrix4fv(projectionLocation, false, projection);
    gl.uniformMatrix4fv(modelLocation, false, model);
    gl.drawArrays(gl.TRIANGLES, 0, vertexCount);

    requestAnimationFrame(render);
}

var currentVersion = -1;
var events = new EventSource("/events");

events.onopen = function() {
    currentVersion = -1;
    message.style.color = "";
    message.textContent = "Подключено. Ожидание вершин...";
};

events.onmessage = function(event) {
    var state = JSON.parse(event.data);

    if (state.type !== "vertices" || state.version <= currentVersion) {
        return;
    }

    if (!Array.isArray(state.data) || state.data.length % 8 !== 0) {
        showError("Сервер отправил неверный массив вершин");
        return;
    }

    currentVersion = state.version;
    vertices = new Float32Array(state.data);
    vertexCount = vertices.length / 8;

    gl.bindBuffer(gl.ARRAY_BUFFER, vertexBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.DYNAMIC_DRAW);

    message.textContent = "Вершин: " + vertexCount + " · треугольников: " + vertexCount / 3;
};

events.onerror = function() {
    showError("Соединение потеряно. Повторное подключение...");
};

requestAnimationFrame(render);
