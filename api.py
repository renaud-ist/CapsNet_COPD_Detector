import os
import io
import numpy as np
import tensorflow as tf
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from PIL import Image
from tensorflow import keras

# -------------------------------
# CONFIGURATION
# -------------------------------
IMG_HEIGHT = 128
IMG_WIDTH = 128
MODEL_PATH = "capsnet_copd_best.h5"

# Load trained model
model = keras.models.load_model(
    MODEL_PATH,
    compile=False
)

# Initialize FastAPI app
app = FastAPI(title="COPD Detection API", description="Detect COPD from Chest X-ray images using CapsNet", version="1.0")

# -------------------------------
# IMAGE PREPROCESSING
# -------------------------------
def preprocess_image(image: Image.Image):
    image = image.resize((IMG_WIDTH, IMG_HEIGHT))
    image = np.array(image).astype("float32") / 255.0
    if image.ndim == 2:  # grayscale to RGB
        image = np.stack((image,) * 3, axis=-1)
    image = np.expand_dims(image, axis=0)
    return image

# -------------------------------
# PREDICTION ENDPOINT
# -------------------------------
@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents)).convert("RGB")
        processed_image = preprocess_image(image)

        num_classes = 2
        dummy_mask = np.zeros((1, num_classes))

        preds, _ = model.predict([processed_image, dummy_mask])
        preds = preds[0]

        response = {
            "filename": file.filename,
            "predictions": preds.tolist(),
            "class": int(np.argmax(preds)),
            "confidence": float(np.max(preds))
        }
        return JSONResponse(content=response)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# -------------------------------
# ROOT ENDPOINT
# -------------------------------
@app.get("/")
async def root():
    return {"message": "COPD Detection API is running."}
