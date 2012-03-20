package Mojolicious::Plugin::MooseForm;
use Mojo::Base 'Mojolicious::Plugin';
use Carp;
use v5.10;

sub register {
   my $self = shift;
   my $app  = shift;
   my $conf = shift;
   my $test_value_url = $conf->{test_value_url} || "/__attribute_ajax__/test_value/:name";
   croak "test_value_url must have a parameter 'name'" unless $test_value_url =~ m{[\.:*]name(?:/|$)};
   my $test_urls = $conf->{test_urls} // 1;

   $app->helper("params_class" => sub{
      my $self  = shift;
      my $class = shift;

      my ( $error, $par, $type, $val );
   
      my $params = {};
      for( $self->param ) {
         $params->{ $_ }      = $self->param( $_ ) ;
         $self->stash->{ $_ } = $self->param( $_ ) ;
      }
      my $obj = eval{ $class->new( $params ) } ;
      if( $@ ) {
         $params ||= {};
         $error = (split/\n/,$@)[0];
         $error =~ s{\s+at\s+/.*?/\w*?.pm\s+line\s+\d+$}{};
         ($par, $type, $val) = $error =~ /\((\w+)\).*?(?:"(\w+)".*?value\s+(.*))?$/g;
         $app->log->debug( $error ) ;
         $self->flash( { error_str => $error } );
         $self->flash( { parameter => $par   } );
         $self->flash( { par_type  => $type  } );
         $self->flash( { par_value => $val   } );
         for( $self->param ) {
            $self->flash( { $_ => $self->param( $_ ) } );
         }
      }
      
      $self->stash->{error_str} = $error;
      $self->stash->{parameter} = $par;
      $self->stash->{par_type } = $type;
      $self->stash->{par_value} = $val;
   
      return $obj;
   });
   
   $app->helper("get_defaults" => sub{
      my $self  = shift;
      my $class = shift;

      my $meta = $class->meta;
      for($meta->get_all_attributes) {
         $self->stash->{$_->name} = "";
         if($_->is_default_a_coderef) {
            $self->stash->{$_->name} = $_->default->($self);
         } else {
            $self->stash->{$_} = $_->default;
         }
      }
      $self->stash->{ attributes } = [
         map {
            {
               title => join(" ", map{ "\u$_" } split /_+/, $_->name),
               name  => $_->name,
               value => $self->flash($_->name) || $_->default,
               doc   => $_->documentation,
               type  => $_->type_constraint,
               req   => $_->is_required,
            }
         } $meta->get_all_attributes
      ];
   
      $self->stash->{error_str} = "";
      $self->stash->{parameter} = "";
      $self->stash->{par_type } = "";
      $self->stash->{par_value} = "";
   
      $self->stash->{error_str} = $self->flash( "error_str" ) if $self->flash( "error_str" );
      $self->stash->{parameter} = $self->flash( "parameter" ) if $self->flash( "parameter" );
      $self->stash->{par_type } = $self->flash( "par_type"  ) if $self->flash( "par_type"  );
      $self->stash->{par_value} = $self->flash( "par_value" ) if $self->flash( "par_value" );
   });

   $app->routes->get("/js/test_values_from/*url" => sub{ 
      my $self = shift;
      my $url  = $self->stash->{url};
      $self->render( inline => << 'END_HTML', url => $url, test_value_url => $test_value_url );
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
                     //document.getElementById(myform[i].name).style.position         = "relative";
                     myform[i].parentNode.parentNode.onmouseover = undefined;
                     myform[i].parentNode.parentNode.onmouseout  = undefined;
                  } else {
                     document.getElementById(myform[i].name).style.display          = "none";
                     document.getElementById(myform[i].name).style.border           = "1px solid black";
                     document.getElementById(myform[i].name).style.backgroundColor  = "white";
                     //document.getElementById(myform[i].name).style.position         = "absolute";
                     myform[i].parentNode.parentNode.onmouseover = function(){this.parentNode.rows[ this.rowIndex + 1 ].style.display = "block"}
                     myform[i].parentNode.parentNode.onmouseout  = function(){this.parentNode.rows[ this.rowIndex + 1 ].style.display = "none"}
                  }
               }
            }
            return test;
         }
END_HTML
   } => "__js_test_values_from__");
    
   $app->helper("create_form_for" => sub {
      my $self  = shift;

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
                     <% given( $attr->{type} ) { %>
                        <% when( "Bool" ) { %>
                           <input
                            type="checkbox"
                            name="<%= $attr->{name} =%>"
                            value="1"
                            <% if($attr->{value}) { =%>"
                               checked=1
                            <% } =%>
                           >
                        <% } %>

                        <% default { %>
                           <input
                            type="text"
                            name="<%= $attr->{name} =%>"
                            value="<%= $attr->{value} =%>"
                           >
                           <% if($attr->{req}) { =%>
                              <span style="color: red">*</span>
                           <% } =%>
                        <% } %>
                     <% } =%>
                  </td>
               </tr>
               <% if($attr->{doc}) { =%>
                  <tr>
                     <td
                      colspan=2
                      id="<%= $attr->{name} =%>"
                      style="position: relative; display: none; background-color: white; border: 1px solid black;"
                     >
                        <%= $attr->{doc} =%>
                     </td>
                  </tr>
               <% } =%>
            <% } %>
            <tr><td colspan=2><input type=submit value="OK"></td></tr>
         </table>
      </form>
      <script>
         for( var i = 0; i < document.forms.length; i++ ) 
            document.forms[ i ].onsubmit = test_values_from;
      </script>
END_HTML
   });
   
   $app->routes->add_shortcut( "form" => sub { 
      my $self   = shift;
      my $url    = shift;
      my @scalar = grep {not ref $_}               @_;
      my @code   = grep {ref $_ eq "CODE"}         @_;
      my @hash   = grep {ref $_ eq "HASH"}         @_;
      my @pars   = grep {ref $_ and ref $_ ne "HASH" and ref $_ ne "CODE"} @_;

      my $stash = shift @hash || {};   

      my $class = shift @scalar;

      my $created_form;

      my $pname = pop @scalar;
      my $gname = pop @scalar;

      $created_form = $app->create_form_for($url) if not $gname;
   
      push @pars, $pname if $pname;
   
      my $post_orig = pop @code;
      my $get_orig  = pop @code;

      my @attrs = $class->meta->get_attribute_list;

      if($test_urls) {
         $self->get($url . $test_value_url, [name => [@attrs]] => sub {
            my $self = shift;
            my $name = $self->param("name");
            my $attr = $class->meta->get_attribute($name);
            eval{ $attr->verify_against_type_constraint( $self->param("value") ) };
            return $self->render_text("OK") unless $@;
            my $error = (split/\n/,$@)[0];
            $error =~ s{\s+at\s+/.*?/\w*?.pm\s+line\s+\d+$}{};
            $self->render_text($error);
         });
      }

      my $post      = sub {
         my $self = shift;
         my $obj  = $self->params_class($class);
         return $self->$post_orig( $obj, @_ )  if $obj;
         $self->redirect_to;
      };
      my $get       = sub {
         my $self = shift;
         $self->get_defaults($class);
         for(keys %$stash){
            $self->stash->{$_} = $stash->{$_};
         }
         if( $get_orig ) {
            return $self->$get_orig( @_ ) ;
         }
         return $self->render( $gname ) if not $created_form;
         $self->render( inline => $created_form, url_form => $url );
      };
      $self->get ($url, $get , @pars);
      $self->post($url, $post, @pars);
   });
   
   *main::form = sub{ $app->routes->form( @_ ) };
}

42
