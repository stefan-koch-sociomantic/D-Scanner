//          Copyright Brian Schott (Hackerpilot) 2014.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)

module symbol_finder;

import std.stdio : File;
import std.d.lexer;
import std.d.parser;
import std.d.ast;
import std.stdio;
import std.file:isFile;

void findDeclarationOf(File output, string symbolName, string[] fileNames)
{
	import std.array : uninitializedArray, array;
	import std.conv : to;
	LexerConfig config;
	StringCache cache = StringCache(StringCache.defaultBucketCount);
	auto visitor = new FinderVisitor(output, symbolName);
	foreach (fileName; fileNames)
	{
		File f = File(fileName);
		assert (isFile(fileName));
		if (f.size == 0) continue;
		auto bytes = uninitializedArray!(ubyte[])(to!size_t(f.size));
		f.rawRead(bytes);
		auto tokens = getTokensForParser(bytes, config, &cache);
		Module m = parseModule(tokens.array, fileName, null, &doNothing);
		visitor.fileName = fileName;
		visitor.visit(m);
	}
}

private:

void doNothing(string, size_t, size_t, string, bool) {}

class FinderVisitor : ASTVisitor
{
	this(File output, string symbolName)
	{
		this.output = output;
		this.symbolName = symbolName;
	}

	mixin generateVisit!FunctionDeclaration;
	mixin generateVisit!ClassDeclaration;
	mixin generateVisit!InterfaceDeclaration;
	mixin generateVisit!StructDeclaration;
	mixin generateVisit!UnionDeclaration;
	mixin generateVisit!TemplateDeclaration;

	override void visit(const Declarator dec)
	{
		if (dec.name.text == symbolName)
			output.writefln("%s(%d:%d)", fileName, dec.name.line, dec.name.column);
	}

	override void visit (const AutoDeclaration ad)
	{
		foreach (id; ad.identifiers)
		{
			if (id.text == symbolName)
				output.writefln("%s(%d:%d)", fileName, id.line, id.column);
		}
	}

	override void visit(const FunctionBody) {}

	mixin template generateVisit(T)
	{
		override void visit(const T t)
		{
			if (t.name.text == symbolName)
				output.writefln("%s(%d:%d)", fileName, t.name.line, t.name.column);
			t.accept(this);
		}
	}

	alias visit = ASTVisitor.visit;

	File output;
	string symbolName;
	string fileName;
}