#ifndef JULIAGD_H
#define JULIAGD_H

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/core/object.hpp>
#include <godot_cpp/godot.hpp>
#include <windows.h>
#include <iostream>
#include <string>
#include <tchar.h>
#include <stdio.h> 
#include <strsafe.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {

class JuliaMDP : public Node {
	GDCLASS(JuliaMDP, Node)

	HANDLE juliaStd_IN_Rd = NULL;
	HANDLE juliaStd_IN_Wr = NULL;
	HANDLE juliaStd_OUT_Rd = NULL;
	HANDLE juliaStd_OUT_Wr = NULL;
	SECURITY_ATTRIBUTES saAttr;
	PROCESS_INFORMATION piProcInfo;

protected:
	static void _bind_methods();

public:
	void _ready();
	void init_julia();
	void create_julia_child();
	void send_to_julia(String msg);
	String read_from_julia();
	void ErrorExit(PCTSTR lpszFunction);

	String create_random_dungeon();
	String create_dungeon();
	String init_MDP(String mdp_json);

	JuliaMDP();
	~JuliaMDP();
};

}

#endif