//
// Mad Project
// 
// Standard object definitions
// 
// Author: Michael McClennen
// Copyright (c) 2010 University of Wisconsin-Madison
// 
// This file defines a series of object classes that form a base set
// available to Mad programmers.
//

namespace Mad {
  namespace Object {
    class BaseValue {
      
    public:
      
      double value;
      
      BaseValue ();
      BaseValue (double);
    };
  };
};


Mad::Object::BaseValue::BaseValue ()
{
  value = 0.0;
}


Mad::Object::BaseValue::BaseValue (double a)
{
  value = a;
}


