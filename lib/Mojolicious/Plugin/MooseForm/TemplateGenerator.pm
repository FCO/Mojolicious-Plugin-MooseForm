package Mojolicious::Plugin::MooseForm::TemplateGenerator;
use Moose;
use v5.10;

has plugins => ( is => 'ro', isa => "ArrayRef", default =>sub{ [] } ) ;

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
            var xmlhttp = new XMLHttpRequest();
            var url = "<%= $url . $test_value_url =%>";
            console.log( this ); 
            var myform = this.getElementsByTagName("INPUT");
            var test = true;
            for(var i = 0; i < myform.length; i++) {
               if(myform[i].name != undefined && myform[i].name != "") {
                  var new_url = url.replace(/:name/, myform[i].name);
                  xmlhttp.open("GET", new_url + "?value=" + myform[i].value, false);
                  xmlhttp.send();
                  test = test && xmlhttp.responseText == "OK";
                  if( xmlhttp.responseText != "OK" ) {
                     document.getElementById(myform[i].name).style.display          = "block";
                     document.getElementById(myform[i].name).style.border           = "1px solid red";
                     document.getElementById(myform[i].name).style.backgroundColor  = "#ffaaaa";
                     myform[i].parentNode.parentNode.onmouseover = undefined;
                     myform[i].parentNode.parentNode.onmouseout  = undefined;
                  } else {
                     document.getElementById(myform[i].name).style.display          = "none";
                     document.getElementById(myform[i].name).style.border           = "1px solid black";
                     document.getElementById(myform[i].name).style.backgroundColor  = "white";
                     myform[i].parentNode.parentNode.onmouseover = function(){this.parentNode.rows[ this.rowIndex + 1 ].style.display = "block"}
                     myform[i].parentNode.parentNode.onmouseout  = function(){this.parentNode.rows[ this.rowIndex + 1 ].style.display = "none"}
                  }
               }
            }
            return test;
         }
END_HTML
}

sub create_form_for {
   return << 'END_HTML';
   <script src="<%= url_for( "__js_test_values_from__", url => $url_form ) =%>"></script>
   <span class="error"><%= $error_str =%></span>
   <form method=post>
      <table width=100%>
         <% for my $attr(sort { $a->{ name } cmp $b->{ name }  } @$attributes) { %>
            <tr
             <% if($attr->{doc}) { =%>
                onmouseover='document.getElementById("<%= $attr->{name} =%>").style.display = "block"'
                onmouseout='document.getElementById("<%= $attr->{name} =%>").style.display = "none"'
             <% } =%>
            >
               <td>
                  <%= $attr->{title} =%>: 
               </td>
               <td>
                  <%= b($get_template->("template_for_type", $c, $attr->{ type }, { attr => $attr } )) =%>
               </td>
            </tr>
            <% if($attr->{doc}) { =%>
               <tr>
                  <td
                   colspam=2
                   id="<%= $attr->{name} =%>"
                   style="position: relative; display: none; background-color: white; border: 1px solid black;"
                  >
                     <%= $attr->{doc} =%>
                  </td>
               </tr>
            <% } =%>
         <% } %>
         <tr><td colspam=2><input type=submit value="OK"></td></tr>
      </table>
   </form>
   <script>
      for( var i = 0; i < document.forms.length; i++ ) 
         document.forms[ i ].onsubmit = test_values_from;
   </script>
END_HTML
}

sub template_for_type { 
   my $tempGen = shift;
   my $self    = shift;
   my $type    = shift;
   my $stash   = shift;
   $type = lc $type;

   my $output;
   $stash->{ template } = "template_for_type_$type";
   if( ($output) = $self->app->renderer->render($self, $stash) ) {
      return $output;
   }
   given( $type ) { 
      when( "bool" ) { 
         ( $output ) = $self->app->renderer->render( $self, { %$stash, inline => << 'END_TYPE' } );
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
      when( "default" ) { 
           ( $output ) = $self->app->renderer->render( $self, { %$stash, inline => << 'END_TYPE' } );
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
      default {
           ( $output ) = $self->app->renderer->render( $self, { %$stash, inline => << 'END_TYPE' } );
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
   }
   return $output
}


42
