@license{
  Copyright (c) 2009-2011 CWI
  All rights reserved. This program and the accompanying materials
  are made available under the terms of the Eclipse Public License v1.0
  which accompanies this distribution, and is available at
  http://www.eclipse.org/legal/epl-v10.html
}
@contributor{Mark Hills - Mark.Hills@cwi.nl (CWI)}
module lang::php::analysis::evaluators::MagicConstants

// TODO: The current parse format does not distinguish between a 
// namespace with an empty body and a namespace given without
// brackets. Until this is fixed, assume here that an empty body 
// is a namespace without brackets.

// TODO: Add support for __TRAIT__. We aren't encountering this yet in code.

import lang::php::ast::AbstractSyntax;
import Set;
import List;
import String;
import Exception;

@doc{Replace magic constants with their actual values.}
public Script inlineMagicConstants(Script scr, loc l) {
	// First, replace any magic constants that require context. This includes
	// __CLASS__, __METHOD__, __FUNCTION__, __NAMESPACE__, and __TRAIT__.
	scr = top-down visit(scr) {
		case c:class(className,_,_,_,members) : {
			members = bottom-up visit(members) {
				case s:scalar(classConstant()) => scalar(string(className))[@at=s@at]
			}
			insert(c[members=members]);
		}
		
		case m:method(methodName,_,_,_,body) : {
			body = bottom-up visit(body) {
				case s:scalar(methodConstant()) => scalar(string(methodName))[@at=s@at]
			}
			insert(m[body=body]);
		}
		
		case f:function(funcName,_,_,body) : {
			body = bottom-up visit(body) {
				case s:scalar(funcConstant()) => scalar(string(funcName))[@at=s@at]
			}
			insert(f[body=body]);
		}
		
		case n:namespace(maybeName,body) : {
			// NOTE: In PHP, a namespace without a name is used to
			// include global code in a file with a namespace declaration.

			namespaceName = "";
			if (someName(name(str nn)) := maybeName) namespaceName = nn;
			body = bottom-up visit(body) {
				case s:scalar(namespaceConstant()) => scalar(string(namespaceName))[@at=s@at]
			}
			insert(n[body=body]);
		}
	}
	
	// Now, replace those magic constants that do not require any context,
	// such as __FILE__ and __DIR__. Also replace the magic constants that
	// do require context with "", this means they were used outside of a
	// valid context (e.g., __CLASS__ outside of a class).
	scr = bottom-up visit(scr) {
		case s:scalar(classConstant()) => scalar(string(""))[@at=s@at]
		case s:scalar(methodConstant()) => scalar(string(""))[@at=s@at]
		case s:scalar(funcConstant()) => scalar(string(""))[@at=s@at]
		case s:scalar(namespaceConstant()) => scalar(string(""))[@at=s@at]

		case s:scalar(fileConstant()) => scalar(string(l.path))[@at=s@at]
		case s:scalar(dirConstant()) => scalar(string(l.parent.path))[@at=s@at]

		case s:scalar(lineConstant()) : {
			try {
				insert(scalar(integer(s@at.begin.line))[@at=s@at]);
			} catch UnavailableInformation() : {
				println("Tried to extract line number from location <s@at> with no line number information");
			}
		}
	}
	return scr;
}