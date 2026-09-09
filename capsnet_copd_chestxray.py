import os
import numpy as np
import matplotlib.pyplot as plt
import tensorflow as tf
from tensorflow import keras
from keras import layers
from keras.preprocessing.image import ImageDataGenerator

# -------------------------------
# CONFIGURATION
# -------------------------------
IMG_HEIGHT = 128
IMG_WIDTH = 128
BATCH_SIZE = 32
EPOCHS = 50
DATASET_DIR = "./chest_xray_dataset"  # Update with your dataset path

# -------------------------------
# DATA PREPROCESSING & AUGMENTATION
# -------------------------------
train_datagen = ImageDataGenerator(
    rescale=1.0/255,
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    fill_mode='nearest',
    validation_split=0.1  # 10% validation from training set
)

train_generator = train_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_HEIGHT, IMG_WIDTH),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    subset='training'
)

val_generator = train_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_HEIGHT, IMG_WIDTH),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    subset='validation'
)

# Separate test set loader (20% of data)
test_datagen = ImageDataGenerator(rescale=1.0/255)
test_generator = test_datagen.flow_from_directory(
    DATASET_DIR,
    target_size=(IMG_HEIGHT, IMG_WIDTH),
    batch_size=BATCH_SIZE,
    class_mode='categorical',
    shuffle=False
)

# -------------------------------
# CAPSULE NETWORK LAYERS
# -------------------------------
class Squash(layers.Layer):
    def call(self, inputs):
        s_squared_norm = tf.reduce_sum(tf.square(inputs), axis=-1, keepdims=True)
        scale = s_squared_norm / (1 + s_squared_norm)
        return scale * inputs / tf.sqrt(s_squared_norm + keras.backend.epsilon())

class CapsuleLayer(layers.Layer):
    def __init__(self, num_capsules, dim_capsule, routings=3, **kwargs):
        super(CapsuleLayer, self).__init__(**kwargs)
        self.num_capsules = num_capsules
        self.dim_capsule = dim_capsule
        self.routings = routings

    def build(self, input_shape):
        self.W = self.add_weight(
            shape=[input_shape[-1], self.num_capsules * self.dim_capsule],
            initializer='glorot_uniform',
            trainable=True
        )

    def call(self, inputs):
        u_hat = tf.tensordot(inputs, self.W, axes=1)
        u_hat = tf.reshape(u_hat, (-1, inputs.shape[1], self.num_capsules, self.dim_capsule))
        b = tf.zeros_like(u_hat[:, :, :, 0])

        for i in range(self.routings):
            c = tf.nn.softmax(b, axis=2)
            s = tf.reduce_sum(tf.expand_dims(c, -1) * u_hat, axis=1)
            v = Squash()(s)
            if i < self.routings - 1:
                b += tf.reduce_sum(u_hat * tf.expand_dims(v, 1), axis=-1)
        return v

# -------------------------------
# LOSS FUNCTIONS
# -------------------------------
def margin_loss(y_true, y_pred):
    m_plus, m_minus, lambda_val = 0.9, 0.1, 0.5
    L = y_true * tf.square(tf.maximum(0., m_plus - y_pred)) + \
        lambda_val * (1 - y_true) * tf.square(tf.maximum(0., y_pred - m_minus))
    return tf.reduce_mean(tf.reduce_sum(L, axis=1))

# -------------------------------
# BUILDING THE CAPSNET MODEL
# -------------------------------
inputs = keras.Input(shape=(IMG_HEIGHT, IMG_WIDTH, 3))
x = layers.Conv2D(64, (3, 3), activation='relu', padding='same')(inputs)
x = layers.Conv2D(128, (3, 3), activation='relu', padding='same')(x)
x = layers.Reshape((-1, 128))(x)

caps = CapsuleLayer(num_capsules=2, dim_capsule=16, routings=3)(x)
output_caps = layers.Lambda(lambda z: tf.sqrt(tf.reduce_sum(tf.square(z), axis=-1)))(caps)

# Decoder network for reconstruction
mask = layers.Input(shape=(2,))
y_masked = layers.Multiply()([caps, tf.expand_dims(mask, -1)])
y_flat = layers.Flatten()(y_masked)
recon = layers.Dense(512, activation='relu')(y_flat)
recon = layers.Dense(1024, activation='relu')(recon)
reconstruction = layers.Dense(IMG_HEIGHT * IMG_WIDTH * 3, activation='sigmoid')(recon)
reconstruction = layers.Reshape((IMG_HEIGHT, IMG_WIDTH, 3))(reconstruction)

# Full model
model = keras.Model([inputs, mask], [output_caps, reconstruction])

# Combined loss
def combined_loss(y_true, y_pred):
    y_true_label, y_true_image = y_true
    y_pred_label, y_pred_image = y_pred
    return margin_loss(y_true_label, y_pred_label) + \
           keras.losses.mse(tf.reshape(y_true_image, [-1, IMG_HEIGHT * IMG_WIDTH * 3]),
                            tf.reshape(y_pred_image, [-1, IMG_HEIGHT * IMG_WIDTH * 3]))

model.compile(optimizer=keras.optimizers.Adam(learning_rate=0.001),
              loss=[margin_loss, 'mse'],
              loss_weights=[1.0, 0.0005],
              metrics={'capsule_layer': 'accuracy'})

model.summary()

# -------------------------------
# CALLBACKS
# -------------------------------
checkpoint = keras.callbacks.ModelCheckpoint(
    'capsnet_copd_best.h5', monitor='val_loss', save_best_only=True, verbose=1
)

# -------------------------------
# TRAINING
# -------------------------------
history = model.fit(
    [train_generator, train_generator.labels],
    [train_generator.labels, train_generator],
    validation_data=([val_generator, val_generator.labels], [val_generator.labels, val_generator]),
    epochs=EPOCHS,
    callbacks=[checkpoint]
)

# -------------------------------
# VISUALIZE TRAINING RESULTS
# -------------------------------
plt.plot(history.history['capsule_layer_accuracy'], label='train acc')
plt.plot(history.history['val_capsule_layer_accuracy'], label='val acc')
plt.legend()
plt.show()
