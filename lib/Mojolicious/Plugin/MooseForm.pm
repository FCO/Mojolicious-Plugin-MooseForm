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

   $app->helper("create_test_value_js_func" => sub {
      my $self  = shift;
      my $url   = shift;

      return << "END_HTML";
      <script>
         var xmlhttp = new XMLHttpRequest();
         function test_values_from(class) {
            var url = "$url$test_value_url";
            var myform = document.forms[class].getElementsByTagName("INPUT");
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
                     document.getElementById(myform[i].name).style.position         = "relative";
                     myform[i].onmouseover = undefined;
                     myform[i].onmouseout  = undefined;
                  } else {
                     document.getElementById(myform[i].name).style.display          = "none";
                     document.getElementById(myform[i].name).style.border           = "1px solid black";
                     document.getElementById(myform[i].name).style.backgroundColor  = "white";
                     document.getElementById(myform[i].name).style.position         = "absolute";
                     var name = myform[i].name;
                     myform[i].onmouseover = function(){document.getElementById(name).style.display = "block"}
                     myform[i].onmouseout  = function(){document.getElementById(name).style.display = "none"}
                  }
               }
            }
            return test;
         }
      </script>
END_HTML
   });
    

   $app->helper("create_form_for" => sub {
      my $self  = shift;
      my $class = shift;
      my $url   = shift;

      return (($test_urls ? $self->create_test_value_js_func($url) : "") . << "END_HTML");
      <span class="error"><%= \$error_str =%></span>
      <form name="$class" method=post>
         <% for my \$attr(\@\$attributes) { %>
            <%= \$attr->{name} =%>: 
            <input
             type="text"
             name="<%= \$attr->{name} =%>"
             value="<%= \$attr->{value} =%>"
             <% if(\$attr->{doc}) { =%>
                onmouseover='document.getElementById("<%= \$attr->{name} =%>").style.display = "block"'
                onmouseout='document.getElementById("<%= \$attr->{name} =%>").style.display = "none"'
             <% } =%>
            >
            <% if(\$attr->{req}) { =%>
               <span style="color: red">*</span>
            <% } =%>
            <BR>
             <% if(\$attr->{doc}) { =%>
                <span id="<%= \$attr->{name} =%>" style="position: relative; display: none; background-color: white; border: 1px solid black;">
                   <%= \$attr->{doc} =%>
                </span>
             <% } =%>
         <% } %>
         <input type=submit value="OK" onclick="return test_values_from($class)">
      </form>
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

      my $pname = pop @scalar;
      my $gname = pop @scalar;

      my $created_form = $app->create_form_for($class, $url) if not $gname;
   
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
         return $self->render( $gname ) if $gname;
         $self->render( inline => $created_form );
      };
      $self->get ($url, $get , @pars);
      $self->post($url, $post, @pars);
   });
   
   *main::form = sub{ $app->routes->form( @_ ) };
}

42
