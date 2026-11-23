import io
import sys
import pymeshio
from pymeshio import common, pmx
from pymeshio.pmx import reader, writer


def run_test():
  print(f"[Python] Версия интерпретатора: {sys.version.split()[0]}")
  print(f"[pymeshio] Путь к пакету: {pymeshio.__file__}")

  # 1. Создаем тестовую модель в памяти (1 треугольник)
  model = pmx.Model()
  model.name = "EmbeddedTestModel"

  v0 = pmx.Vertex(
      common.Vector3(0.0, 0.0, 0.0),
      common.Vector3(0.0, 0.0, 1.0),
      common.Vector2(0.0, 0.0),
      pmx.Bdef1(0),
      0.0,
  )
  v1 = pmx.Vertex(
      common.Vector3(1.0, 0.0, 0.0),
      common.Vector3(0.0, 0.0, 1.0),
      common.Vector2(1.0, 0.0),
      pmx.Bdef1(0),
      0.0,
  )
  v2 = pmx.Vertex(
      common.Vector3(0.0, 1.0, 0.0),
      common.Vector3(0.0, 0.0, 1.0),
      common.Vector2(0.0, 1.0),
      pmx.Bdef1(0),
      0.0,
  )

  model.vertices = [v0, v1, v2]
  model.indices = [0, 1, 2]

  # 2. Записываем модель в буфер в памяти
  buf = io.BytesIO()
  writer.write(buf, model)
  raw_bytes = buf.getvalue()
  print(f"[pymeshio] Успешная сериализация в PMX ({len(raw_bytes)} байт)")

  # 3. Читаем модель обратно из буфера
  buf.seek(0)
  loaded = reader.read(buf)
  assert loaded is not None, "Ошибка чтения PMX из буфера"
  assert len(loaded.vertices) == 3, "Неверное количество вершин"

  print(
      f"[pymeshio] Успешное чтение: '{loaded.name}', вершин:"
      f" {len(loaded.vertices)}"
  )
  return True
