package Mojolicious::Plugin::MooseForm;
use Mojo::Base 'Mojolicious::Plugin';
use Mojolicious::Plugin::MooseForm::TemplateGenerator;
use Carp;
use v5.10;

sub register {
   my $self = shift;
   my $app  = shift;
   my $conf = shift;
   my $test_value_url = $conf->{test_value_url} || "/__attribute_ajax__/test_value/:name";
   croak "test_value_url must have a parameter 'name'" unless $test_value_url =~ m{[\.:*]name(?:/|$)};
   my $test_urls = $conf->{test_urls} // 1;
   $conf->{ bgcolor } ||= [ "#E6E6FA", "white" ];

   my $tempGen = Mojolicious::Plugin::MooseForm::TemplateGenerator->new;
   if(exists $conf->{plugin}) {
      for(@{ref $conf->{plugin} eq "ARRAY" ? $conf->{plugin} : [$conf->{plugin}]}) {
         $tempGen->add_plugin($_);
      }
   }

   $app->helper("params_class" => sub{
      my $self  = shift;
      my $class = shift;
      $self->stash->{ bgcolor } = $conf->{ bgcolor };

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
      $self->stash->{ bgcolor } = $conf->{ bgcolor };

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
            my $val;
            if($self->flash( $_->name ) ) {
               $val = $self->flash( $_->name );
               #if( ref $val ) {
               #   
               #}
            } else {
               $val = $_->is_default_a_coderef
                      ? $_->default->($class)
                      : $_->default;
            }
            {
               title => join(" ", map{ "\u$_" } split /_+/, $_->name),
               name  => $_->name,
               value => $val,
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
      $self->render( inline => $tempGen->get_template( "js_test_values_from"), url => $url, test_value_url => $test_value_url );
   } => "__js_test_values_from__");
    
   $app->helper("template_is_setted" => sub{
      my $self = shift;
      my $stash = $self->stash;

      my $template = $stash->{template};
      unless ($template) {
         if ($self->match->endpoint) {
           $template = $self->match->endpoint->name;
         }
      }
      return !! $template;
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

   
      #push @pars, $pname if $pname;
   
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
            $self->$get_orig( @_ ) ;
         }
         $self->stash->{ template } = $gname if $gname;
         if($self->app->renderer->render($self, $self->stash)) {
            return $self->render;
         } else {
            #return $self->render( $gname ) if $gname;
            $created_form = $tempGen->get_template( "create_form_for", $url);
            $self->render( inline => $created_form, url_form => $url, get_template => sub { $tempGen->get_template( @_ ) }, c => $self );
         }
      };
      $self->get ($url, $get , @pars, $gname);
      $self->post($url, $post, @pars, $pname);
   });
   
   *main::form = sub{ $app->routes->form( @_ ) };
}

42
