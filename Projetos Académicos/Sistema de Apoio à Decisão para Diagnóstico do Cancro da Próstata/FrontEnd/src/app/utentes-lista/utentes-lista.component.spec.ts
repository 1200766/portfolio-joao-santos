import { ComponentFixture, TestBed } from '@angular/core/testing';

import { UtentesListaComponent } from './utentes-lista.component';

describe('UtentesListaComponent', () => {
  let component: UtentesListaComponent;
  let fixture: ComponentFixture<UtentesListaComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [ UtentesListaComponent ]
    })
    .compileComponents();

    fixture = TestBed.createComponent(UtentesListaComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
