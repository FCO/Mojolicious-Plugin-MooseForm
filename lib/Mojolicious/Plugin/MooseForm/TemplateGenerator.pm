package Mojolicious::Plugin::MooseForm::TemplateGenerator;
use Moose;
use v5.10;
use Data::Dumper;

has plugins => ( is => 'ro', isa => "ArrayRef", default => sub{ [] } ) ;

sub get_template {
   my $self = shift;
   my $name = shift;

   for( @{ $self->plugins }  ) {
      return $_->$name( @_ ) if $_->can($name);
   }
   $self->$name( @_ );
}

sub add_plugin {
   my $self   = shift;
   my $plugin = shift;
   $plugin = $plugin->new if not ref $plugin and $plugin->can( "new" ) ;
   push @{ $self->plugins }, $plugin;
}

sub js_test_values_from {
   return << 'END_HTML';
      function test_values_from() {
         var test = true;
         var xmlhttp = new XMLHttpRequest();
         var url = "<%= $url . $test_value_url =%>";
         var rows = this.getElementsByTagName("TR");
         for(var i = 0; i < rows.length; i++) {
         console.log( i ) ;
            var _this = rows[ i ];
            var attr_name = _this.getAttribute( "attr" ); 
            if(attr_name != null ) { 
               console.log("iteracao");
               var new_url = url.replace(/:name/, attr_name );
               var inputs  = _this.getElementsByTagName( "INPUT" );
               var myquery = "";

               for( var j = 0; j < inputs.length; j++ ) 
                  if(myquery == "")
                     myquery = "?value=" + inputs[ j ].value;
                  else
                     myquery += "&value=" + inputs[ j ].value;

               var my_url = new_url + myquery;
               console.log("my_url: " + my_url);
               xmlhttp.open("GET", my_url, false);
               xmlhttp.send();
               test = test && xmlhttp.responseText == "OK";
               if( xmlhttp.status != 200 ) {
                  test = false;
                  return;
               }
               var doc = _this.getElementsByClassName("documentation")[ 0 ];
               if( doc != null ) { 
                  if(xmlhttp.responseText != "OK") {
                     doc.style.display          = "block";
                     doc.style.border           = "1px solid red";
                     doc.style.backgroundColor  = "#ffaaaa";
                     doc.style.position         = "relative";
                     doc.getElementsByClassName("validation_error")[ 0 ].innerHTML = ":<BR>" + xmlhttp.responseText;
                  } else {
                     doc.style.display          = "none";
                     doc.style.border           = "1px solid black";
                     doc.style.backgroundColor  = "white";
                     doc.getElementsByClassName("validation_error")[ 0 ].innerHTML = "";
                  }
               }
            }
         }
         return test;
      }
END_HTML
}

sub create_form_for {
   return << 'END_HTML';
   <% my $line = 0; %>
   <script src="<%= url_for( "__js_test_values_from__", url => $url_form ) =%>"></script>
   <span class="error"><%= $error_str =%></span>
   <form
    method=post
    onsubmit="this.onsubmit = test_values_from; return this.onsubmit()"
   >
      <table width=100%>
         <% for my $attr(sort { $a->{ name } cmp $b->{ name }  } @$attributes) { %>
            <tr
             style="background-color: <%= $bgcolor->[ $line++ % 2 ] =%>"
             attr="<%= $attr->{ name }  =%>"
            >
               <td>
                  <%= $attr->{title} =%>: 
                  <span
                   id="<%= $attr->{name} =%>"
                   class="documentation"
                   style="position: absolute; display: none; background-color: white; border: 1px solid black;"
                  >
                     <% if($attr->{doc}) { =%>
                        <%= $attr->{doc} =%>
                     <% } =%>
                     <span
                      class="validation_error"
                     >
                     </span>
                  </span>
               </td>
               <td>
                  <%= b($get_template->("render_type", $c, $attr->{ type }, { attr => $attr } )) =%>
               </td>
            </tr>
         <% } %>
         <tr><td colspan=2><input type=submit value="OK"></td></tr>
      </table>
   </form>
END_HTML
}

sub render {
   my $self  = shift;
   my $c     = shift;
   my $stash = $c->stash;
   my $template = shift;
   $stash->{ template } = $template;
   my $output;
   if( ($output) = $c->app->renderer->render($c, $stash) ) {
      return $output;
   }
   ( $output ) = $c->app->renderer->render( $c, { %$stash, inline => $self->get_template($template, $c, $stash, @_) } );
   $output;
}

sub render_type { 
   my $self   = shift;
   my $c      = shift;
   my $type   = shift;
   my $stash  = shift;

   my $sub_type;
   if( defined $type ) {
      $sub_type = $1 if $type =~ s/\[\s*(.*)\s*]\s*$//;
      $type = lc $type;
   } else {
      $type = "default";
   }

   $c->stash->{$_} = $stash->{$_} for keys %$stash;

   my $output = $self->render($c, "template_for_type_$type", $sub_type);
   return $output if $output;
   $self->render($c, "template_for_type_default");
}
sub template_for_type_arrayref {
   my $self  = shift;
   my $c     = shift;
   my $stash = shift;
   my $type  = shift;
   my $def_arr = delete $stash->{ attr }->{ value } ;
   my @type_template;
   
   my $type_template = $self->render_type($c, $type, $stash);

   for(@$def_arr) { 
      $stash->{ attr }->{ value } = "$_";
      push @type_template, $self->render_type($c, $type, $stash);
   }

   $stash->{ arr_type_template } = [ @type_template ];
   $stash->{ attr }->{ value } = $def_arr;

   return << "END_TYPE";
      <div
       style="display: none"
       id="<%= \$attr->{ name } =%>_template"
      >
      $type_template<br>
      </div>
      <div id="<%= \$attr->{ name } =%>_div">
         <% for my \$def(\@\$arr_type_template) { %>
               <%= b(\$def) =%><br>
         <% } %>
      </div>
      <button
       onclick="document.getElementById('<%= \$attr->{ name } =%>_div').innerHTML += document.getElementById('<%= \$attr->{ name } =%>_template').innerHTML; return false;"
      > + </button>
END_TYPE
}

sub template_for_type_bool { 
   return << 'END_TYPE';
      <input
       type="checkbox"
       name="<%= $attr->{name} =%>"
       value="1"
       <% if($attr->{value}) { =%>"
          checked=1
       <% } =%>
      >
END_TYPE
}
sub template_for_type_num { 
   return << 'END_TYPE';
      <input
       type="text"
       name="<%= $attr->{name} =%>"
       value="<%= $attr->{value} =%>"
      >
      <% if($attr->{req}) { =%>
         <span style="color: red">*</span>
      <% } =%>
END_TYPE
}
sub template_for_type_str { 
   return << 'END_TYPE';
      <input
       type="text"
       name="<%= $attr->{name} =%>"
       value="<%= $attr->{value} =%>"
      >
      <% if($attr->{req}) { =%>
         <span style="color: red">*</span>
      <% } =%>
END_TYPE
}
sub template_for_type_default {
   my $self = shift;
   $self->template_for_type_str
}


42
