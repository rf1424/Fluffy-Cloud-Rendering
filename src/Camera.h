#pragma once

#include <glm/ext.hpp>
#include <GLFW/glfw3.h>
#include <glfw3webgpu.h>


struct DragState {
	bool dragging = false;
	glm::vec2 startMousePos = glm::vec2(0.);
	glm::vec2 startCameraAngles = glm::vec2(0.);
};

class Camera
{

public:


	// interaction state
	DragState dragState;

	// camera state
	// Camera framing tuned for the current model composition.
	glm::vec2 angles = { glm::pi<float>() / 2.0f, 0.1f }; // in radians
	float zoom = -0.2f;

	glm::mat4 projMatrix = glm::perspective(glm::radians(45.0f), 640.0f / 480.0f, 0.1f, 1000.0f);
	

public:
	
	void getViewMatrix(glm::mat4& outViewMatrix);
	void getProjMatrix(glm::mat4& outModelMatrix) { outModelMatrix = projMatrix; }
};
