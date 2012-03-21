use Mojolicious::Lite;
BEGIN{ plugin "Mojolicious::Plugin::MooseForm", test_urls => 1 }

use BlaBleBli;

post "/" => sub {
   my $self = shift;
   my $obj  = $self->params_class("BlaBleBli");
   return $self->render_text( "foi: " . $obj->bla ) if $obj;
   $self->redirect_to("/");
};

get "/" => sub {
   my $self = shift;
   $self->get_defaults("BlaBleBli");
   $self->render( "form" );
} => "form";

form "/test_with_name", "BlaBleBli" => sub {
   my $self = shift;
   my $obj  = shift;
   $self->render_text( "form test: " . $obj->bla ) ;
} => "form" => "form";

form "/test", "BlaBleBli" => sub {
   my $self = shift;
   my $obj  = shift;
   $self->render_text( "form test: " . join " - ", @{ $obj->array_of_strs2 } ) ;
};

app->start


__DATA__

@@ form.html.ep

<strong><%= $error_str =%></strong>
<form method=POST>
   <input type=test name=bla value="<%= $bla =%>">
   <input type=submit value=OK>
</form>

@@ template_for_type_bool.html.ep

<input
 type="checkbox"
 name="<%= $attr->{name} =%>"
 value="1"
 <% if($attr->{value}) { =%>"
    checked=1
 <% } =%>
> from __DATA__

