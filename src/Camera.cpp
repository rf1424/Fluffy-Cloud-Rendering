#include "Camera.h"

// camera position in Cartesian coords from angles and r (y is up!!!)
void Camera::getViewMatrix(glm::mat4& outViewMatrix) {
    float cx = glm::cos(angles.x);
    float sx = glm::sin(angles.x);
    float cy = glm::cos(angles.y);
    float sy = glm::sin(angles.y);

    glm::vec3 position = glm::vec3(
        cx * cy,
        sy,
        sx * cy
    ) * std::exp(-zoom);

    glm::mat4 viewMatrix = glm::lookAt(position, glm::vec3(0.0f), glm::vec3(0, 1, 0));
    outViewMatrix = viewMatrix;
}